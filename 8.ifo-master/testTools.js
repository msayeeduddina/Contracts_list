const { ethers, upgrades, network } = require('hardhat')

module.exports.toWei = n => ethers.BigNumber.from(10).pow(18).mul(n)
module.exports.toBN = n => ethers.BigNumber.from(n)
module.exports.numberLastBlock = async () => (await ethers.provider.getBlock('latest')).number
module.exports.timeStampLastBlock = async () => (await ethers.provider.getBlock('latest')).timestamp

module.exports.extractCost = (tx, additionalData = {}, COIN_PRICE = 400) => {
    const GAS_SPENT = +tx.gasUsed
    const GAS_PRICE = 5e9
    const WEI_PRICE = COIN_PRICE/1e18

    const COST_BNB  = +(GAS_SPENT * GAS_PRICE / 1e18).toFixed(6)
    const COST_USD  = +(GAS_SPENT * GAS_PRICE * WEI_PRICE).toFixed(2)

    const BLOCK_NUMBER = tx.blockNumber
    const ACCOUNT = tx.from.slice(0,8)

    let res = {
        GAS_SPENT,
        COST_BNB,
        COST_USD,
        BLOCK_NUMBER,
        ACCOUNT
    }

    return Object.assign(res, additionalData)
}

module.exports.passTime = async ms => {
    await network.provider.send('evm_increaseTime', [ms])
    await network.provider.send('evm_mine')
}