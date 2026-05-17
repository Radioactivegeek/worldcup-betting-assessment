# Architecture

## 1. Project Overview
- Purpose: prediction markets platform with on-chain markets, betting, position trading, and reputation tracking.
- Main features: multi-outcome markets, ETH and ERC20 betting, arbitrator resolution, secondary market for positions, and reputation scoring.
- Tech stack:
  - Smart contracts: Solidity 0.8.30, Hardhat, OpenZeppelin.
  - Frontend: Next.js 15, React 19, TypeScript, Tailwind, Wagmi, Viem, RainbowKit.

## 2. Contract Architecture
- WorldCupBetting
  - Purpose: assessment contract that mirrors the prediction market behaviors needed by the test suite.
  - Key functions: createMarket, placeBet, resolveMarket, claimWinnings, listPosition, cancelListing, buyPosition, withdrawFees.
  - Notes: fee deducted at resolution and stored in availableFees; payoutPerShare scaled by 1e18.
- PredictionMarket
  - Purpose: reference/production-like contract used in docs and deployment scripts.
  - Key functions: createMarket, placeBet, resolveMarket, claimWinnings, listPosition, cancelListing, buyPosition, withdrawFees, getMarket.
  - Notes: tracks outcome pools/shares and dynamic pricing in calculateShares and getPrice.
- ReputationSystem
  - Purpose: track user performance with reputation, totals, and accuracy stats.
  - Key functions: setPredictionMarket, updateReputation, getReputation, getWeight, getStats.
  - Dependency: onlyPredictionMarket modifier enforces authorized updates.
- MockERC20
  - Purpose: test ERC20 token used for USDC-like markets.
  - Key functions: mint, standard ERC20 transfers/approvals.

Relationships and dependencies:
- WorldCupBetting and PredictionMarket both call ReputationSystem.updateReputation.
- ReputationSystem is linked to a prediction market address during deployment.
- MockERC20 is used for ERC20 market tests and scripts.

## 3. Deployment Scripts
Scripts directory: contracts/scripts
- claim-winning.ts: iterates test accounts and claims winnings for resolved markets; uses local RPC and hardcoded addresses.
- create-market.ts: creates a market on a deployed PredictionMarket at a hardcoded address.
- deploy.ts: deploys ReputationSystem, PredictionMarket, and MockERC20; links reputation to market.
- get-market.ts: enumerates markets, prints details, and falls back to events for outcomes.
- place-bet.ts: places multiple ETH bets from hardcoded accounts on a hardcoded market id.
- resolve-market.ts: resolves a market, optionally advancing time on local network.
- test-all.ts: integration flow that creates multiple markets, places bets, trades positions, resolves, claims, and withdraws fees.

Required parameters and env vars for scripts:
- deploy.ts: uses default Hardhat signer, no env vars required.
- test-all.ts: requires REPUTATION_ADDRESS, MARKET_ADDRESS, USDC_ADDRESS.
- All other scripts use hardcoded addresses and local RPC.

## 4. Network Configuration
Hardhat config: contracts/hardhat.config.ts
- Networks:
  - hardhat: chainId 31337.
  - localhost: http://127.0.0.1:8545, chainId 31337.
  - sepolia: RPC from SEPOLIA_RPC_URL, accounts from PRIVATE_KEY.
- Etherscan: ETHERSCAN_API_KEY for verification.
- Accounts/signers: local networks provide default Hardhat accounts; Sepolia uses PRIVATE_KEY.

## 5. Testing Setup
- Test suite: contracts/test/WorldCupBetting.assessment.test.ts
- Scenarios A-I: market creation/resolution, fee payouts, time gating, access control, slippage guard, secondary market, ERC20 markets, and claim idempotency.
- Fixture: deploys ReputationSystem, WorldCupBetting or PredictionMarket, and MockERC20; connects contracts.
- Helpers: @nomicfoundation/hardhat-network-helpers time.latest and time.increaseTo.
- Mocks: MockERC20 used for ERC20 scenario tests.

## 6. Current Implementation Status
- WorldCupBetting: implemented with full lifecycle, fee accounting, and secondary market logic.
- PredictionMarket: complete reference contract with AMM-like pricing and fee handling.
- ReputationSystem: complete and linked to the prediction market via setPredictionMarket.
- MockERC20: complete test token with public mint.
- Deployments: scripts exist for local and Sepolia deployment but no committed deployment artifacts.

## 7. How to Run
- Compile:
  - cd contracts
  - npx hardhat compile
- Test:
  - cd contracts
  - npx hardhat test
  - npx hardhat test test/WorldCupBetting.assessment.test.ts
- Deploy:
  - cd contracts
  - npx hardhat run scripts/deploy.ts --network localhost
  - npx hardhat run scripts/deploy.ts --network sepolia
- Integration script:
  - cd contracts
  - npx hardhat run scripts/test-all.ts --network sepolia

## 8. File Structure
prediction-markets/
├── app/
│   ├── create/page.tsx
│   ├── marketplace/page.tsx
│   ├── markets/page.tsx
│   ├── markets/[id]/page.tsx
│   ├── portfolio/page.tsx
│   ├── layout.tsx
│   ├── page.tsx
│   └── globals.css
├── components/
│   ├── layout/{header.tsx,footer.tsx}
│   ├── market/{activity-feed.tsx,market-card.tsx,market-overview-chart.tsx,market-stats-card.tsx,outcome-bars.tsx,price-history-chart.tsx}
│   ├── portfolio/{bet-history-item.tsx,list-position-dialog.tsx,marketplace-positions.tsx,position-card.tsx,stats-card.tsx}
│   ├── providers/{theme-provider.tsx,web3-provider.tsx}
│   ├── ui/{alert.tsx,badge.tsx,button.tsx,card.tsx,dialog.tsx,form.tsx,input.tsx,label.tsx,progress.tsx,radio-group.tsx,skeleton.tsx,table.tsx,tabs.tsx,textarea.tsx,tooltip.tsx}
│   ├── CreateMarketForm.tsx
│   ├── CreateMarketFormDynamic.tsx
│   └── ResolveMarketDialog.tsx
├── contracts/
│   ├── contracts/{WorldCupBetting.sol,PredictionMarket.sol,ReputationSystem.sol,MockERC20.sol}
│   ├── scripts/{claim-winning.ts,create-market.ts,deploy.ts,get-market.ts,place-bet.ts,resolve-market.ts,test-all.ts}
│   ├── test/{PredictionMarket.test.ts,WorldCupBetting.assessment.test.ts}
│   ├── hardhat.config.ts
│   ├── package.json
│   └── .env.example
├── docs/
│   ├── 01-overview.md
│   ├── 02-smart-contracts.md
│   ├── 03-market-lifecycle.md
│   ├── 04-position-trading.md
│   ├── 05-reputation-system.md
│   ├── 06-frontend-architecture.md
│   ├── 07-hooks-and-data.md
│   ├── 08-ui-components.md
│   ├── 09-development-setup.md
│   ├── 10-deployment.md
│   ├── 11-user-flows.md
│   ├── 12-api-reference.md
│   └── TESTING.md
├── lib/
│   ├── contracts/{addresses.ts,abis/{index.ts,MockERC20.json,PredictionMarket.json,ReputationSystem.json}}
│   ├── hooks/{useBet.ts,useCreateMarket.ts,useEventHistory.ts,useMarketplaceListings.ts,useMarkets.ts,usePortfolio.ts,usePositionTrading.ts,usePriceHistory.ts,useStats.ts}
│   ├── utils/{cn.ts,format.ts}
│   ├── utils.ts
│   └── wagmi.ts
├── public/{file.svg,globe.svg,next.svg,vercel.svg,window.svg}
├── README.md
├── next.config.ts
├── package.json
└── tsconfig.json
