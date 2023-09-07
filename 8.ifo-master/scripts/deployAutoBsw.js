//npx hardhat run scripts/deployAutoBsw.js --network mainnetBSC

const { ethers, network } = require('hardhat')

const BSW_mainnet = '0x965F527D9159dCe6288a2219DB51fc6Eef120dD1'
const MASTERCHEF_mainnet = '0xDbc1A13490deeF9c3C12b44FE77b503c1B061739'
const TREASURY = `0xd3a70caa19d72D9Ed09520594cae4eeA7812Ab51`//'0x9Ee7A44E6FD36f3415848362cf88dE42941540a7' //TODO check when deploy in Mainnet!!!

const main = async () => {
    const [deployer] = await ethers.getSigners()
    console.log(`Deployer address: ${deployer.address}`)
    let nonce = await network.provider.send('eth_getTransactionCount', [deployer.address, 'latest']) - 1

    const AutoBsw = await ethers.getContractFactory('AutoBsw')
    const autoBsw = await AutoBsw.deploy(
        BSW_mainnet,
        MASTERCHEF_mainnet,
        TREASURY,
        {
            nonce: ++nonce,
            gasLimit: 5000000
        }
    )
    await autoBsw.deployed();

    console.log(`autoBsw deployed to: ${autoBsw.address}`)
}

main().then(() => process.exit(0)).catch(e => {console.error(e) && process.exit(1)})





