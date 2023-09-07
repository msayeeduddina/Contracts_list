const NomiswapRouter = artifacts.require('NomiswapRouter')

const contractAddresses = {
  'testnet': {
    factory: '0x818339b4E536E707f14980219037c5046b049dD4',
    weth: '0xae13d989dac2f0debff460ac112a837c89baa7cd',
  },
  'mainnet': {
    factory: '0xd6715A8be3944ec72738F0BFDC739d48C3c29349',
    weth: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
  }
}

module.exports = async function (deployer, network) {
  // Deploy the NomiswapRouter contract as our only task

  const FACTORY_ADDRESS = contractAddresses[network].factory
  const WETH_ADDRESS = contractAddresses[network].weth

  await deployer.deploy(NomiswapRouter, FACTORY_ADDRESS, WETH_ADDRESS)
}
