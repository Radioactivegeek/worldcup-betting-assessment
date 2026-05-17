# ⚽ WorldCupBetting — On-Chain Betting Smart Contract

> Solidity assessment: a fully implemented on-chain prediction market for World Cup match betting with multi-outcome markets, ERC-20 support, secondary position trading, and a reputation system.

---

## 📋 Assessment Overview

This repository contains the implementation of `WorldCupBetting.sol` — a smart contract that supports the full lifecycle of a decentralized betting market. The contract was built to satisfy **9 assessment scenarios (A–I)** covering market creation, resolution, fee accounting, access control, slippage protection, position trading, ERC-20 collateral, and claim idempotency.

| Deliverable | Location |
|---|---|
| **Smart Contract** | [`WorldCupBetting.sol`](./WorldCupBetting.sol) (root copy) · [`contracts/contracts/WorldCupBetting.sol`](./contracts/contracts/WorldCupBetting.sol) |
| **Test Suite** | [`contracts/test/WorldCupBetting.assessment.test.ts`](./contracts/test/WorldCupBetting.assessment.test.ts) |
| **Implementation Notes** | [`IMPLEMENTATION_NOTES.md`](./IMPLEMENTATION_NOTES.md) |
| **Architecture** | [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| **Submission Checklist** | [`SUBMISSION.md`](./SUBMISSION.md) |

---

## ✅ Scenarios Implemented

| # | Scenario | Description | Status |
|---|---|---|---|
| **A** | Group-stage 1X2 | Three-outcome market (Brazil/Draw/Serbia) — create, bet, resolve, verify status | ✅ Pass |
| **B** | Knockout yes/no + fees | Two-sided ETH pool — winner receives net payout after 2% fee; owner withdraws fees | ✅ Pass |
| **C** | Time gate (resolve) | Oracle cannot resolve before `resolutionTime` — reverts with `"Too early"` | ✅ Pass |
| **D** | Access control | Random fan cannot resolve — reverts with `"Only arbitrator"` | ✅ Pass |
| **E** | Time gate (bets) | No bets at or after resolution timestamp — reverts with `"Market closed"` | ✅ Pass |
| **F** | Slippage guard | `placeBet` with `_minShares = MaxUint256` — reverts with `"Slippage exceeded"` | ✅ Pass |
| **G** | Secondary market | List position → buy position → new owner claims winnings after resolution | ✅ Pass |
| **H** | ERC-20 collateral | Full lifecycle (bet, resolve, claim) using a mock USDC token | ✅ Pass |
| **I** | Loser settles + no double-claim | Losing side calls `claimWinnings` (records reputation, zero payout); second call reverts `"Already claimed"` | ✅ Pass |

---

## 🔗 Deployment

| Detail | Value |
|---|---|
| **Network** | Sepolia Testnet |
| **Contract Address** | `<PASTE_ADDRESS_HERE>` |
| **Etherscan** | [`View on Etherscan`](https://sepolia.etherscan.io/address/<PASTE_ADDRESS_HERE>) |
| **Solidity Version** | `0.8.30` |

> ⚠️ Replace `<PASTE_ADDRESS_HERE>` with the actual deployed contract address.

---

## 🚀 Quick Start

### Prerequisites

- **Node.js** ≥ 18
- **npm** ≥ 9

### Install & Test

```bash
# Clone the repository
git clone https://github.com/Radioactivegeek/worldcup-betting-assessment.git
cd worldcup-betting-assessment

# Install contract dependencies
cd contracts
npm install --legacy-peer-deps

# Compile
npx hardhat compile

# Run all assessment tests
npx hardhat test
```

### Expected Output

```
  World Cup on-chain betting (assessment scenarios)
    ✔ Scenario A: group-stage match with three outcomes (1X2)
    ✔ Scenario B: knockout yes/no market — winner receives net payout after platform fee
    ✔ Scenario C: oracle cannot resolve before kickoff window closes
    ✔ Scenario D: random fan cannot resolve the match
    ✔ Scenario E: no new stakes after the official resolution timestamp
    ✔ Scenario F: slippage guard rejects bets when minShares is too high
    ✔ Scenario G: secondary market — ticket buyer collects if seller picked the winner
    ✔ Scenario H: stablecoin pool — same lifecycle using ERC20 collateral
    ✔ Scenario I: losing side can settle to record reputation without double-claim

  9 passing
```

---

## 📁 Project Structure

```
worldcup-betting-assessment/
├── WorldCupBetting.sol              # ← Main contract (root copy for easy review)
├── README.md                        # This file
├── IMPLEMENTATION_NOTES.md          # Design decisions & assumptions
├── ARCHITECTURE.md                  # Full architecture documentation
├── SUBMISSION.md                    # Assessment submission checklist
├── LICENSE
│
├── contracts/                       # Hardhat project
│   ├── contracts/                   # Solidity source files
│   │   ├── WorldCupBetting.sol      #   Assessment contract (canonical)
│   │   ├── PredictionMarket.sol     #   Reference/production contract
│   │   ├── ReputationSystem.sol     #   Reputation tracking
│   │   └── MockERC20.sol            #   Test ERC-20 token
│   ├── test/                        # Test suites
│   │   ├── WorldCupBetting.assessment.test.ts   # 9 assessment scenarios
│   │   └── PredictionMarket.test.ts             # Reference contract tests
│   ├── scripts/                     # Deployment & utility scripts
│   │   ├── deploy-worldcup.ts       #   Deploy WorldCupBetting + Reputation
│   │   ├── deploy.ts                #   Deploy PredictionMarket stack
│   │   └── test-all.ts              #   Integration test script
│   ├── hardhat.config.ts            # Hardhat configuration
│   ├── package.json                 # Contract dependencies
│   └── .env.example                 # Environment variable template
│
├── assessment/                      # Assessment instructions (provided)
│   └── instructions.md
│
└── docs/                            # Extended documentation
    ├── 01-overview.md
    ├── 02-smart-contracts.md
    ├── ...
    └── TESTING.md
```

---

## 🔒 Security Features

- **ReentrancyGuard** — All state-changing functions that transfer funds are protected against reentrancy attacks (OpenZeppelin).
- **Checks-Effects-Interactions** — State mutations occur before external calls in `claimWinnings` and `buyPosition`.
- **Access Control** — `onlyOwner` for `createMarket` and `withdrawFees`; per-market arbitrator for `resolveMarket`.
- **Time Gating** — Bets rejected at or after `resolutionTime`; resolution rejected before `resolutionTime`.
- **Slippage Protection** — `_minShares` parameter prevents front-running on bet placement.
- **Scaled Math** — `payoutPerShare` uses `1e18` scaling to preserve precision during integer division.
- **No Double Claims** — `claimed` flag on each bet prevents re-entrancy via repeated `claimWinnings` calls.

---

## 🧪 Test Coverage

| Category | Coverage |
|---|---|
| Market lifecycle (create → bet → resolve → claim) | ✅ |
| Fee accounting (2% deduction + owner withdrawal) | ✅ |
| Time-based access control | ✅ |
| Role-based access control (arbitrator / owner) | ✅ |
| Slippage protection | ✅ |
| Secondary market (list → buy → claim) | ✅ |
| ERC-20 collateral flow | ✅ |
| Edge cases (loser claim, double-claim revert) | ✅ |

---

## 🚢 Deployment to Sepolia

```bash
# 1. Configure environment
cp contracts/.env.example contracts/.env
# Edit contracts/.env with your keys:
#   SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
#   PRIVATE_KEY=your_wallet_private_key
#   ETHERSCAN_API_KEY=your_etherscan_api_key

# 2. Deploy
cd contracts
npx hardhat run scripts/deploy-worldcup.ts --network sepolia

# 3. Verify on Etherscan
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <REPUTATION_ADDRESS>
```

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| Smart Contracts | Solidity 0.8.30, OpenZeppelin 5.x |
| Dev Framework | Hardhat 2.x |
| Testing | Mocha, Chai, Hardhat Network Helpers |
| Language | TypeScript |

---

## 📬 Contact

- **Candidate**: *Your Name*
- **Email**: *your.email@example.com*
- **GitHub**: [Radioactivegeek](https://github.com/Radioactivegeek)

---

*Built as part of the Smart Contract Engineer assessment.*
