//npx hardhat run scripts/deployIDOVesting.js --network mainnetBSC

const { ethers, network, upgrades } = require('hardhat')
const {toWei} = require("../testTools");


const vestingBlockOffset = 28800 * 30; //30 days
const autoBswAddress = `0xa4b20183039b2F9881621C3A03732fBF0bfdff10`;

const dealTokenAddress = '0x965F527D9159dCe6288a2219DB51fc6Eef120dD1' //BSW
const offerTokenAddress = `0x16b8dBa442cc9fAa40d0Dd53f698087546CCF096` //EXOS


const poolLimited = {
    raisingAmount: toWei(298500),
    offeringAmount: toWei(2500000),
    minLimitPerUserInDealToken: 0,
    maxLimitPerUserInDealToken: toWei(239),
    totalAmount: 0,
    stakeRequirement: toWei(50)
}

const poolUnlimited = {
    raisingAmount: toWei(895500),
    offeringAmount: toWei(7500000),
    minLimitPerUserInDealToken: toWei(60),
    maxLimitPerUserInDealToken: toWei(23895),
    totalAmount: 0,
    stakeRequirement: toWei(150)
}

const numberLastBlock = async () => (await ethers.provider.getBlock('latest')).number;


const main = async () => {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${deployer.address}`);

    let curBlock = await numberLastBlock();
    let startBlock = 17680674 //curBlock + 20; //17680674 Tue May 10 2022 14:01:32 GMT+0300
    let finishBlock = startBlock + 1200; //1 hour


    const Ido = await ethers.getContractFactory(`IDOVesting`);
    // const idoAddress = ``
    // let ido = await Ido.attach(idoAddress);
    // let ido = await upgrades.upgradeProxy(idoAddress, Ido)

    let ido = await upgrades.deployProxy(
        Ido,
        [
            dealTokenAddress,
            offerTokenAddress,
            startBlock,
            finishBlock,
            vestingBlockOffset,
            autoBswAddress
            ],
        );
    await ido.deployed();

    console.log(`Ido deployed to: ${ido.address}`)
    console.log(`start block ${startBlock} \nfinish block ${finishBlock} curBlock ${curBlock}`)
    let nonce = await network.provider.send('eth_getTransactionCount', [deployer.address, 'latest']) - 1

    console.log(`Set pools`)
    await ido.setPool(poolLimited, 0, {nonce: ++nonce, gasLimit: 3e6});
    await ido.setPool(poolUnlimited, 1, {nonce: ++nonce, gasLimit: 3e6});
    // await ido.updateStartAndEndBlocks(startBlock, finishBlock, {nonce: ++nonce, gasLimit: 3e6});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
