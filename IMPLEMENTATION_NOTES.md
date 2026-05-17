# Implementation Notes

## Architecture Overview
- Market lifecycle: owner creates a market, users place bets until resolution time, arbitrator resolves, winners claim payouts.
- Bet flow: stake sent in ETH or ERC20, shares computed 1:1, pool grows, outcome resolved, payout per share calculated once.
- Secondary market: bet owner lists a position, buyer pays seller, ownership of the bet is transferred, buyer can later claim.

## Scenario B Fee Flow
- At resolution, 2% of the total pool is recorded as protocol fees in availableFees.
- The remaining 98% becomes the net pool for winners and is stored as a scaled payoutPerShare.
- The owner withdraws fees using withdrawFees, which transfers the stored amount.

## Scenario G Ownership Transfer
- listPosition creates a listing tied to a bet.
- buyPosition transfers payment to the seller and updates bet.better to the buyer.
- The buyer then claims winnings after resolution using claimWinnings.

## Security Measures
- ReentrancyGuard on state-changing functions that transfer funds.
- onlyOwner for createMarket and withdrawFees.
- Arbitrator-only resolution via a per-market arbitrator address.
- Checks-effects-interactions in claimWinnings and buyPosition transfers.
- Scaled math for payoutPerShare to preserve precision during division.

## Assumptions
- Shares are calculated 1:1 with stake amount for the assessment.
- The reputation system exposes updateReputation(address,bool) and is trusted.
- Markets do not reopen after resolution, and no refund path is provided for markets with zero winners.
