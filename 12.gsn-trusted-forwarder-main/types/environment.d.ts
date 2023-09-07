declare namespace NodeJS {
  export interface ProcessEnv {
    ETHERSCAN_API_KEY?: string;
    ETHEREUM_NODE_MAINNET?: string;
    ETHEREUM_ACCOUNTS_MAINNET?: string;
    ETHEREUM_NODE_KOVAN?: string;
    ETHEREUM_ACCOUNTS_KOVAN?: string;
    ETHEREUM_NODE_RINKEBY?: string;
    ETHEREUM_ACCOUNTS_RINKEBY?: string;
  }
}
