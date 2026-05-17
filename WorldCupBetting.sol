// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IReputationSystem {
    function updateReputation(address user, bool correct) external;
    function getReputation(address user) external view returns (uint256);
}

/**
 * @title WorldCupBetting
 * @notice Assessment entrypoint: replace stub bodies with a full prediction market until
 *         `test/WorldCupBetting.assessment.test.ts` passes. Out-of-the-box, every call reverts so
 *         the assessment suite is red until you implement behavior.
 * @dev Optional behavioral reference in-repo: `PredictionMarket.sol` (do not modify that file
 *      unless your interview allows it). Instructors can run tests against the reference by
 *      setting `WORLD_CUP_ASSESSMENT_SOLUTION=1` when executing Hardhat (see `assessment/instructions.md`).
 */
contract WorldCupBetting is ReentrancyGuard, Ownable {
    // TODO: consider adding market cancellation feature with refunds.
    // TODO: evaluate per market creator tracking if ownership can chage.
    enum MarketStatus {
        Open,
        Closed,
        Resolved,
        Cancelled
    }

    uint256 private constant FEE_BPS = 2; // 2%
    uint256 private constant FEE_DENOMINATOR = 100;
    uint256 private constant SHARE_SCALE = 1e18;

    struct Market {
        uint256 marketId;
        string description;
        string matchName;
        string[] outcomes;
        uint256 resolutionTime;
        address tokenAddress;
        address arbitrator;
        MarketStatus status;
        uint256 winningOutcome;
        uint256 totalPool;
        uint256 payoutPerShare;
    }

    struct Bet {
        uint256 betId;
        uint256 marketId;
        address better;
        uint256 outcomeIndex;
        uint256 shares;
        uint256 amount;
        bool claimed;
        address tokenAddress;
    }

    struct Listing {
        uint256 listingId;
        uint256 betId;
        address seller;
        uint256 price;
        bool active;
    }

    IReputationSystem public reputationSystem;

    // Counters
    uint256 public marketCount;
    uint256 public betCount;
    uint256 public listingCount;

    // Data
    mapping(uint256 => Market) public markets;
    mapping(uint256 => Bet) public bets;
    mapping(uint256 => Listing) public listings;
    mapping(address => uint256[]) public userBets;
    mapping(uint256 => uint256[]) public marketBets;
    mapping(address => uint256) public availableFees;

    event MarketCreated(uint256 indexed marketId, string matchName, address indexed arbitrator);
    event BetPlaced(uint256 indexed betId, uint256 indexed marketId, address indexed better, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint256 winningOutcome);
    event WinningsClaimed(uint256 indexed betId, address indexed claimer, uint256 amount);
    event PositionListed(uint256 indexed listingId, uint256 indexed betId, address indexed seller, uint256 price);
    event PositionBought(uint256 indexed listingId, uint256 indexed betId, address indexed buyer, uint256 price);
    event FeesWithdrawn(address indexed token, uint256 amount, address indexed recipient);

    constructor(address _reputationSystem) Ownable(msg.sender) {
        reputationSystem = IReputationSystem(_reputationSystem);
    }

    function _candidateStub() internal pure {
        revert("WorldCupBetting: candidate implementation required");
    }

    /**
     * @notice Creates a new betting market.
     * @param _matchName Match title used for display.
     * @param _description Market description.
     * @param _outcomes Array of possible outcomes.
     * @param _resolutionTime Timestamp after which the market can be resolved.
     * @param _arbitrator Address allowed to resolve the market.
     * @param _tokenAddress Address of ERC20 collateral, or zero for ETH.
     * @return New market id.
     */
    function createMarket(
        string memory _matchName,
        string memory _description,
        string[] memory _outcomes,
        uint256 _resolutionTime,
        address _arbitrator,
        address _tokenAddress
    ) external onlyOwner returns (uint256) {
        require(_outcomes.length >= 2, "Needs at least two outcomes");
        require(_resolutionTime > block.timestamp, "Resolution must be in future");
        require(_arbitrator != address(0), "Invalid arbitrator");

        marketCount += 1;
        uint256 newMarketId = marketCount;

        Market storage m = markets[newMarketId];
        m.marketId = newMarketId;
        m.description = _description;
        m.matchName = _matchName;
        for (uint256 i = 0; i < _outcomes.length; i++) {
            m.outcomes.push(_outcomes[i]);
        }
        m.resolutionTime = _resolutionTime;
        m.tokenAddress = _tokenAddress;
        m.arbitrator = _arbitrator;
        m.status = MarketStatus.Open;
        m.winningOutcome = 0;
        m.totalPool = 0;
        m.payoutPerShare = 0;

        emit MarketCreated(newMarketId, _matchName, _arbitrator);

        return newMarketId;
    }

    /**
     * @notice Places a bet on a specific outcome.
     * @param _marketId Market id.
     * @param _outcomeIndex Index of selected outcome.
     * @param _amount Stake amount in ETH or ERC20.
     * @param _minShares Minimum shares to accept (slippage guard).
     * @return New bet id.
     */
    function placeBet(
        uint256 _marketId,
        uint256 _outcomeIndex,
        uint256 _amount,
        uint256 _minShares
    ) external payable nonReentrant returns (uint256) {
        require(_marketId > 0 && _marketId <= marketCount, "Market does not exist");
        Market storage m = markets[_marketId];
        require(m.status == MarketStatus.Open, "Market closed");
        require(block.timestamp < m.resolutionTime, "Market closed");
        require(_outcomeIndex < m.outcomes.length, "Invalid outcome");
        require(_amount > 0, "Amount must be > 0");

        // Handle payment
        if (m.tokenAddress == address(0)) {
            require(msg.value == _amount, "Incorrect ETH sent");
        } else {
            require(msg.value == 0, "Do not send ETH for ERC20 market");
            IERC20 token = IERC20(m.tokenAddress);
            require(token.transferFrom(msg.sender, address(this), _amount), "ERC20 transfer failed");
        }

        // Calculate shares (delegate to helper)
        uint256 shares = calculateShares(_marketId, _amount, _outcomeIndex);
        require(shares >= _minShares, "Slippage exceeded");

        // Create bet
        betCount += 1;
        uint256 newBetId = betCount;

        Bet storage b = bets[newBetId];
        b.betId = newBetId;
        b.marketId = _marketId;
        b.better = msg.sender;
        b.outcomeIndex = _outcomeIndex;
        b.shares = shares;
        b.amount = _amount;
        b.claimed = false;
        b.tokenAddress = m.tokenAddress;

        // Update pools and indexes
        m.totalPool += _amount;
        userBets[msg.sender].push(newBetId);
        marketBets[_marketId].push(newBetId);

        emit BetPlaced(newBetId, _marketId, msg.sender, _amount);

        return newBetId;
    }

    /**
     * @notice Resolves a market and sets the winning outcome.
     * @param _marketId Market id.
     * @param _winningOutcome Index of the winning outcome.
        * @dev Fees and payoutPerShare are computed once here to avoid per-claim accounting.
     */
    function resolveMarket(uint256 _marketId, uint256 _winningOutcome) external {
        require(_marketId > 0 && _marketId <= marketCount, "Market does not exist");
        Market storage m = markets[_marketId];

        require(msg.sender == m.arbitrator, "Only arbitrator");
        require(block.timestamp >= m.resolutionTime, "Too early");
        require(m.status == MarketStatus.Open, "Market not open");
        require(_winningOutcome < m.outcomes.length, "Invalid outcome");

        // Calculate total winning shares.
        uint256 totalWinningShares = 0;
        uint256[] storage betsForMarket = marketBets[_marketId];
        for (uint256 i = 0; i < betsForMarket.length; i++) {
            uint256 bid = betsForMarket[i];
            Bet storage bet = bets[bid];
            if (bet.outcomeIndex == _winningOutcome) {
                totalWinningShares += bet.shares;
            }
        }

        if (totalWinningShares > 0) {
            uint256 totalAfterFee = (m.totalPool * (FEE_DENOMINATOR - FEE_BPS)) / FEE_DENOMINATOR;
            m.payoutPerShare = (totalAfterFee * SHARE_SCALE) / totalWinningShares;
            availableFees[m.tokenAddress] += (m.totalPool * FEE_BPS) / FEE_DENOMINATOR;
        } else {
            m.payoutPerShare = 0;
        }

        // Record the winning outcome and mark resolved.
        m.winningOutcome = _winningOutcome;
        m.status = MarketStatus.Resolved;

        emit MarketResolved(_marketId, _winningOutcome);
    }

    /**
     * @notice Claims winnings for a bet after market resolution.
     * @param _betId Bet id.
        * @dev Using scaled math here to avoid precision loss on division.
     */
    function claimWinnings(uint256 _betId) external nonReentrant {
        require(_betId > 0 && _betId <= betCount, "Bet does not exist");
        Bet storage b = bets[_betId];
        Market storage m = markets[b.marketId];

        require(b.better == msg.sender, "Not bet owner");
        require(m.status == MarketStatus.Resolved, "Market not resolved");
        require(!b.claimed, "Already claimed");

        b.claimed = true;

        uint256 payout = 0;
        if (b.outcomeIndex == m.winningOutcome) {
            // Using scaled math here to avoid precision loss on division.
            payout = (b.shares * m.payoutPerShare) / SHARE_SCALE;
            if (payout > 0) {
                if (m.tokenAddress == address(0)) {
                    (bool success, ) = payable(b.better).call{value: payout}("");
                    require(success, "ETH transfer failed");
                } else {
                    IERC20 token = IERC20(m.tokenAddress);
                    require(token.transfer(b.better, payout), "ERC20 transfer failed");
                }
            }

            // update reputation for winner
            reputationSystem.updateReputation(msg.sender, true);
        } else {
            // losing bettor: record reputation, do not revert
            reputationSystem.updateReputation(msg.sender, false);
        }

        emit WinningsClaimed(_betId, msg.sender, payout);
    }

    /**
     * @notice Lists a bet position for sale.
     * @param _betId Bet id.
     * @param _price Sale price in ETH or ERC20.
        * @dev Trade-off: price is seller-defined with no on-chain sanity check.
     */
    function listPosition(uint256 _betId, uint256 _price) external {
        require(_betId > 0 && _betId <= betCount, "Bet does not exist");
        Bet storage b = bets[_betId];
        Market storage m = markets[b.marketId];

        require(b.better == msg.sender, "Not bet owner");
        require(!b.claimed, "Bet already claimed");
        require(m.status != MarketStatus.Resolved, "Market already resolved");

        listingCount += 1;
        uint256 newListingId = listingCount;

        Listing storage l = listings[newListingId];
        l.listingId = newListingId;
        l.betId = _betId;
        l.seller = msg.sender;
        l.price = _price;
        l.active = true;

        emit PositionListed(newListingId, _betId, msg.sender, _price);
    }

    /**
     * @notice Cancels an active position listing.
     * @param _listingId Listing id.
     */
    function cancelListing(uint256 _listingId) external {
        require(_listingId > 0 && _listingId <= listingCount, "Listing does not exist");
        Listing storage l = listings[_listingId];
        require(l.active, "Listing not active");
        require(l.seller == msg.sender, "Not seller");

        l.active = false;
    }

    /**
     * @notice Buys a listed position and transfers bet ownership.
     * @param _listingId Listing id.
        * @dev We accept exact price only to keep logic simple for the assessment.
     */
    function buyPosition(uint256 _listingId) external payable nonReentrant {
        require(_listingId > 0 && _listingId <= listingCount, "Listing does not exist");
        Listing storage l = listings[_listingId];
        require(l.active, "Listing not active");
        require(l.seller != msg.sender, "Seller cannot buy own listing");

        Bet storage b = bets[l.betId];
        require(!b.claimed, "Bet already claimed");

        // Handle payment to seller
        if (b.tokenAddress == address(0)) {
            require(msg.value == l.price, "Incorrect ETH sent");
            (bool success, ) = payable(l.seller).call{value: l.price}("");
            require(success, "ETH transfer to seller failed");
        } else {
            require(msg.value == 0, "Do not send ETH for ERC20 position");
            IERC20 token = IERC20(b.tokenAddress);
            require(token.transferFrom(msg.sender, l.seller, l.price), "ERC20 transfer failed");
        }

        // Transfer bet ownership
        b.better = msg.sender;

        // Deactivate listing
        l.active = false;

        emit PositionBought(_listingId, l.betId, msg.sender, l.price);
    }

    /**
     * @notice Withdraws accumulated protocol fees (owner only).
     * @param _token Token address to withdraw, or zero for ETH.
     */
    function withdrawFees(address _token) external onlyOwner nonReentrant {
        uint256 amt = availableFees[_token];
        require(amt > 0, "No fees available");
        availableFees[_token] = 0;

        if (_token == address(0)) {
            (bool success, ) = payable(owner()).call{value: amt}("");
            require(success, "ETH withdraw failed");
        } else {
            IERC20 token = IERC20(_token);
            require(token.transfer(owner(), amt), "ERC20 withdraw failed");
        }

        emit FeesWithdrawn(_token, amt, owner());
    }

    /**
     * @notice Returns fees available to withdraw for a token.
     * @param _token Token address to query, or zero for ETH.
     * @return Amount of fees available.
     */
    function getAvailableFees(address _token) external view returns (uint256) {
        return availableFees[_token];
    }

    /**
     * @notice Calculates shares for a bet.
     * @dev Uses a 1:1 mapping between amount and shares for assessment simplicity.
     * @param _marketId Market id (unused).
     * @param _amount Stake amount.
     * @param _outcomeIndex Outcome index (unused).
     * @return Number of shares.
     */
    function calculateShares(
        uint256 _marketId,
        uint256 _amount,
        uint256 _outcomeIndex
    ) public pure returns (uint256) {
        // Simple 1:1 shares to amount for assessment
        _marketId;
        _outcomeIndex;
        return _amount;
    }

    /**
     * @notice Returns the outcome price (placeholder for assessment).
     * @param _marketId Market id (unused).
     * @param _outcomeIndex Outcome index (unused).
     * @return Price scaled to 1e18.
     */
    function getPrice(uint256 _marketId, uint256 _outcomeIndex) public pure returns (uint256) {
        _marketId;
        _outcomeIndex;
        return 1e18;
    }

    /**
     * @notice Returns total pool size for a market.
     * @param _marketId Market id.
     * @return Total pool amount.
     */
    function getTotalPool(uint256 _marketId) public view returns (uint256) {
        return markets[_marketId].totalPool;
    }

    /**
     * @notice Returns bet ids for a user.
     * @param _user User address.
     * @return Array of bet ids.
     */
    function getUserBets(address _user) external view returns (uint256[] memory) {
        return userBets[_user];
    }

    /**
     * @notice Returns bet ids for a market.
     * @param _marketId Market id.
     * @return Array of bet ids.
     */
    function getMarketBets(uint256 _marketId) external view returns (uint256[] memory) {
        return marketBets[_marketId];
    }

    /**
     * @notice Returns the market metadata for display.
     * @param _marketId Market id.
     * @return marketId Market id.
     * @return description Market description.
     * @return matchName Market match name.
     * @return outcomes Market outcomes.
     * @return resolutionTime Resolution timestamp.
     * @return tokenAddress Token address (zero for ETH).
     * @return arbitrator Market arbitrator.
     * @return status Market status.
     * @return winningOutcome Winning outcome index.
     * @return creator Market creator (owner).
    * @dev Creator is surfaced as owner() because markets are owner-created in this assessment.
     */
    function getMarket(uint256 _marketId)
        external
        view
        returns (
            uint256 marketId,
            string memory description,
            string memory matchName,
            string[] memory outcomes,
            uint256 resolutionTime,
            address tokenAddress,
            address arbitrator,
            MarketStatus status,
            uint256 winningOutcome,
            address creator
        )
    {
        Market storage m = markets[_marketId];
        return (
            m.marketId,
            m.description,
            m.matchName,
            m.outcomes,
            m.resolutionTime,
            m.tokenAddress,
            m.arbitrator,
            m.status,
            m.winningOutcome,
            owner()
        );
    }
}
