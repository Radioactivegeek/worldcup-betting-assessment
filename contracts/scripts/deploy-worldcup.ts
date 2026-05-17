import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Using account:", deployer.address);

  console.log("Deploying ReputationSystem...");
  const ReputationSystem = await ethers.getContractFactory("ReputationSystem");
  const reputationSystem = await ReputationSystem.deploy();
  await reputationSystem.waitForDeployment();
  const repAddress = await reputationSystem.getAddress();
  console.log("ReputationSystem:", repAddress);

  console.log("Deploying WorldCupBetting...");
  const WorldCupBetting = await ethers.getContractFactory("WorldCupBetting");
  const worldCupBetting = await WorldCupBetting.deploy(repAddress);
  await worldCupBetting.waitForDeployment();
  const marketAddress = await worldCupBetting.getAddress();
  console.log("WorldCupBetting:", marketAddress);

  console.log("Linking ReputationSystem to WorldCupBetting...");
  const linkTx = await reputationSystem.setPredictionMarket(marketAddress);
  const linkReceipt = await linkTx.wait(2);
  console.log("Linked in block:", linkReceipt?.blockNumber ?? "unknown");

  console.log("\n=== SAVE THESE ADDRESSES ===");
  console.log("REPUTATION_SYSTEM_ADDRESS=", repAddress);
  console.log("WORLD_CUP_BETTING_ADDRESS=", marketAddress);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
