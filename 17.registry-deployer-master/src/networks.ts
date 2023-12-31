import { NetworksUserConfig } from "hardhat/types";

import config from "./config";

const automineConfig = config.AUTOMINE ? {} : {
  auto: false,
  interval: 3000,
};

export const networks : NetworksUserConfig = {
  hardhat: {
    saveDeployments: false,
    mining: automineConfig,
  },
  localhost: {
    url: "http://localhost:8545",
    saveDeployments: true,
  },
  mumbai: {
    url: config.MUMBAI_RPC_URL,
    accounts: [config.MUMBAI_DEPLOYER_PRIVATE_KEY],
    chainId: 80001,
    verify: {
      etherscan: {
        apiKey: config.MUMBAI_POLYGONSCAN_API_KEY,
        apiUrl: config.MUMBAI_POLYGONSCAN_API_URL,
      },
    },
  },
  polygon: {
    url: config.POLYGON_RPC_URL,
    accounts: [config.POLYGON_DEPLOYER_PRIVATE_KEY],
    chainId: 137,
    verify: {
      etherscan: {
        apiKey: config.POLYGON_POLYGONSCAN_API_KEY,
        apiUrl: config.POLYGON_POLYGONSCAN_API_URL,
      },
    },
  },
  goerli: {
    url: config.GOERLI_RPC_URL,
    accounts: [config.GOERLI_DEPLOYER_PRIVATE_KEY],
    chainId: 5,
    verify: {
      etherscan: {
        apiKey: config.GOERLI_ETHERSCAN_API_KEY,
        apiUrl: config.GOERLI_ETHERSCAN_API_URL,
      },
    },
  },
  fuji: {
    url: config.FUJI_RPC_URL,
    accounts: [config.FUJI_DEPLOYER_PRIVATE_KEY],
    chainId: 43113,
    verify: {
      etherscan: {
        apiKey: config.FUJI_ETHERSCAN_API_KEY,
        apiUrl: config.FUJI_ETHERSCAN_API_URL,
      },
    },
  },
  avalanche: {
    url: config.AVALANCHE_RPC_URL,
    accounts: [config.AVALANCHE_DEPLOYER_PRIVATE_KEY],
    chainId: 43114,
    verify: {
      etherscan: {
        apiKey: config.AVALANCHE_ETHERSCAN_API_KEY,
        apiUrl: config.AVALANCHE_ETHERSCAN_API_URL,
      },
    },
  },
  chapel: {
    url: config.CHAPEL_RPC_URL,
    accounts: [config.CHAPEL_DEPLOYER_PRIVATE_KEY],
    chainId: 97,
    verify: {
      etherscan: {
        apiKey: config.CHAPEL_ETHERSCAN_API_KEY,
        apiUrl: config.CHAPEL_ETHERSCAN_API_URL,
      },
    },
  },
  bsc: {
    url: config.BSC_RPC_URL,
    accounts: [config.BSC_DEPLOYER_PRIVATE_KEY],
    chainId: 56,
    verify: {
      etherscan: {
        apiKey: config.BSC_ETHERSCAN_API_KEY,
        apiUrl: config.BSC_ETHERSCAN_API_URL,
      },
    },
  },
  chiado: {
    url: config.CHIADO_RPC_URL,
    gasPrice: 1000000000,
    accounts: [config.CHIADO_DEPLOYER_PRIVATE_KEY],
    chainId: 10200,
    verify: {
      etherscan: {
        apiKey: config.CHIADO_ETHERSCAN_API_KEY,
        apiUrl: config.CHIADO_ETHERSCAN_API_URL,
      },
    },
  },
  gnosis: {
    url: config.GNOSIS_RPC_URL,
    gasPrice: 10000000000,
    accounts: [config.GNOSIS_DEPLOYER_PRIVATE_KEY],
    chainId: 100,
    verify: {
      etherscan: {
        apiKey: config.GNOSIS_ETHERSCAN_API_KEY,
        apiUrl: config.GNOSIS_ETHERSCAN_API_URL,
      },
    },
  },
};

export default networks;
