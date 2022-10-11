const { ethers, upgrades } = require("hardhat");

async function main() {
    const MPool = await ethers.getContractFactory("MPool");

    console.log("Deploying MPool...");

    const mpool = await upgrades.deployProxy(MPool, ["0x36b9CB8647498b91Db009C978Fbc099818A8Bb26","0xdD5ed879edA28D5A65F6fB4C74de54B5606cA4D2"], {
        initializer: "initialize",
    });
    await mpool.deployed();

    console.log("MPool deployed to:", mpool.address);
}

main();