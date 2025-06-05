const hre = require("hardhat");
const { verify } = require("../utils/verify.js");
require("dotenv").config();

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  // Deploy Cr8or
  const Cr8or = await hre.ethers.deployContract("Cr8or", ["Cr8or", "CR8"]);
  await Cr8or.waitForDeployment();
  console.log("Cr8or Contract Deployed at " + Cr8or.target);
  console.log("");

  // Verify contracts (optional, only if you have an etherscan key and on testnet/mainnet)

  if (network.name !== "hardhat" && network.name !== "localhost") {
    console.log("Verifying contracts...");
    await verify(Cr8or.target, ["Cr8or", "CR8"], "contracts/Cr8or.sol:Cr8or");
  } else {
    console.log("Skipping verification on local network");
  }
  console.log("");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
