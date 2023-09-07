//npx hardhat run scripts/deployDivPool.js --network testnetBSC

const { ethers, network, upgrades } = require('hardhat')

const toBN = (numb, power = 18) =>
    ethers.BigNumber.from(10).pow(power).mul(numb);

const stakeToken = `0x965F527D9159dCe6288a2219DB51fc6Eef120dD1`
const earlyWithdrawalFee = 1000
const feeBase = 10000
const maxStakePerUser = toBN(100000)
const minInitialStake = toBN(1,16)
const lockPeriod = 60 * 24 * 3600
const treasuryAddress = `0xDC255039cc48907D5bE97eAf4Dca20CA97d2cDEe`
const interestPaymentAddress = `0xAF97D8cD8f93e7893c5e5d053d2C1f8D68EBeE38`


const main = async () => {
    const [deployer] = await ethers.getSigners()
    console.log(`Deployer address: ${deployer.address}`)
    let nonce = await network.provider.send('eth_getTransactionCount', [deployer.address, 'latest']) - 1

    const DivPool = await ethers.getContractFactory(`DivPool`);
    let divPool = await upgrades.deployProxy(
        DivPool,
        [
            stakeToken,
            earlyWithdrawalFee,
            feeBase,
            maxStakePerUser,
            minInitialStake,
            lockPeriod,
            treasuryAddress,
            interestPaymentAddress
        ],{ nonce: ++nonce, gasLimit: 5e6 })
    await divPool.deployed();
    ++nonce;
    console.log(`divPool deployed to: ${divPool.address}`)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
