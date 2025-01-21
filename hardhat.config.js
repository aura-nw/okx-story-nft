const fs = require("fs");
const privateKey = fs.readFileSync(".secret").toString().trim();

require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require("hardhat-deploy");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.26",
  settings: {
    optimizer: {
      enabled: true,
      runs: 100,
    },
  },
  defaultNetwork: "hardhat",
  networks: {
    local: {
      url: "http://127.0.0.1:8545",
    },
    hardhat: {
      blockGasLimit: 7000000,
    },
    odyssey: {
      url: "https://odyssey.storyrpc.io",
      chainId: 1516,
      throwOnTransactionFailures: true,
      gasPrice: 100000000,
      accounts: [privateKey],
      gas: 4000000,
      timeout: 120000,
      allowUnlimitedContractSize: true,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  paths: {
    deploy: "scripts/odyssey",
    deployments: "deployments",
  },
};
