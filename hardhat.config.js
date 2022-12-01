require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");

require("dotenv").config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "testnet",
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
    // apiKey: process.env.BSCSCAN_API_KEY,
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      gasPrice: 20000000000,
      accounts: [process.env.PRIVATEKEY],
    },
    hardhat: {},
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [process.env.PRIVATEKEY],
    },
    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 20000000000,
      accounts: [process.env.PRIVATEKEY],
    },
    // rinkeby: {
    //   url: "https://rinkeby.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
    //   chainId: 4,
    //   gasPrice: 20000000000,
    //   accounts: [process.env.PRIVATEKEY],
    // },
    goerli: {
      // url: "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
      // url: "https://eth-goerli.g.alchemy.com/v2/demo",
      url:"https://eth-goerli.public.blastapi.io",
      // url:"https://rpc.ankr.com/eth_goerli",
      // url:"https://rpc.goerli.mudit.blog",
      chainId: 5,
      gasPrice: 20000000000,
      accounts: [process.env.PRIVATEKEY],
    },
  },
  solidity: {
    compilers: [
      {
        // version: "0.5.16",
        // version: "0.7.0",
        // version: "0.7.3",
        //version: "0.8.7",
        // version: "0.8.9",
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true,
        },
      },
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 20000,
  },
};
