const HDWalletProvider = require('truffle-hdwallet-provider')

const mnemonic = process.env.MNEMONIC;
const token = process.env.INFURA_TOKEN;

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      gas: 8000000,
      network_id: "*", // Match any network id
      gasPrice: 1000000000 // 1 Gwei
    },
    rinkeby: {
      provider: () => {
        return new HDWalletProvider(mnemonic, 'https://rinkeby.infura.io/v3/' + token)
      },
      network_id: '4',
      gasPrice: 100000000000, // 25 Gwei
    },
    kovan: {
      provider: () => {
        return new HDWalletProvider(mnemonic, 'https://kovan.infura.io/v3/' + token)
      },
      network_id: '42',
      gas: 4200000,
      gasPrice: 15000000000, // 25 Gwei
    },
    mainnet: {
      provider: () => {
        return new HDWalletProvider(mnemonic, 'https://mainnet.infura.io/v3/' + token)
      },
      network_id: '1',
      gas: 4200000,
      gasPrice: 5000000000, // 25 Gwei
    }
  },
  compilers: {
    solc: {
      settings: {
        optimizer: {
          enabled: false,
          runs: 200
        },
      },
    },
  },
};
