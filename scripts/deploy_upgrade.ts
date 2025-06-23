import { proxyAddress } from "./proxyAddress";

const { ethers, upgrades } = require("hardhat");
async function main() {
  const Cr8or_V2 = await ethers.getContractFactory("Cr8or_V2");
  console.log("Upgrading Cr8or_V2...");
  await upgrades.upgradeProxy(proxyAddress, Cr8or_V2);
  console.log("Cr8or_V2 upgraded");
}

main();
