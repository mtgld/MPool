require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-etherscan");

require("dotenv").config();

module.exports = {
 solidity: "0.8.10",
 networks: {
   goerli: {
        url: "https://goerli.infura.io/v3/33948e9382ea49ac8960a6f92e926e3b",
        accounts: [process.env.PRIVATE_KEY],
   },
   gnosis: {
        url: "https://rpc.gnosischain.com/",
        accounts: [process.env.PRIVATE_KEY],
   },
 },
 etherscan: {
   apiKey: process.env.ETHERSCAN_API_KEY,
 },
};
