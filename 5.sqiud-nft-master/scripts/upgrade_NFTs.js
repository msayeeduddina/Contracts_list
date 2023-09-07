const { ethers, network, upgrades} = require(`hardhat`);

const playerNFTAddress = `0xb00ED7E3671Af2675c551a1C26Ffdcc5b425359b`;
const busNFTAddress = `0x6d57712416eD4890e114A37E2D84AB8f9CEe4752`;
const ownerAddress = `0xbafefe87d57d4c5187ed9bd5fab496b38abdd5ff`;

async function impersonateAccount(acctAddress) {
    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [acctAddress],
    });
    return await ethers.getSigner(acctAddress);
}

async function main() {
    let deployer = network.name === `localhost` ? await impersonateAccount(ownerAddress) : (await ethers.getSigners())[0];
    if(deployer.address.toLowerCase() !== ownerAddress.toLowerCase()){
        console.log(`Change deployer address. Current deployer: ${deployer.address}. Owner: ${ownerAddress}`);
        return;
    }

    // console.log(`Start upgrade Bus NFT contract`);
    // const BusNFT = await ethers.getContractFactory(`SquidBusNFT`, deployer);
    // // await upgrades.forceImport(busNFTAddress, BusNFT);
    // const busNft = await upgrades.upgradeProxy(busNFTAddress, BusNFT);
    // await busNft.deployed();
    // console.log(`Bus NFT upgraded`);

    console.log(`Start upgrade SquidPlayer NFT contract`);
    const PlayerNFT = await ethers.getContractFactory(`SquidPlayerNFT`, deployer);
    // await upgrades.forceImport(playerNFTAddress, PlayerNFT);
    const playerNft = await upgrades.upgradeProxy(playerNFTAddress, PlayerNFT);
    await playerNft.deployed();
    console.log(`Player NFT upgraded`);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
