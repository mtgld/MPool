const { ethers, upgrades } = require("hardhat");

const PROXY = "0xaE41C2E6611B154969BE776eBa63a0C6B428C6b5";

async function main() {
    const MPool = await ethers.getContractFactory("MPool");
    console.log("Upgrading MPool...");
    await upgrades.upgradeProxy(PROXY, MPool);
    console.log("MPool upgraded successfully");
}

main();