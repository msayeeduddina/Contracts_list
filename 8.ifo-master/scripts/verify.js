
const hre = require('hardhat');
const { ethers } = require(`hardhat`);

async function getImplementationAddress(proxyAddress) {
    const implHex = await ethers.provider.getStorageAt(
        proxyAddress,
        "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
    );
    return ethers.utils.hexStripZeros(implHex);
}

async function main() {

    console.log(`Verify IFO contract`);
    res = await hre.run("verify:verify", {
        address: await getImplementationAddress(''),
        constructorArguments: [],
        optimizationFlag: true
    })
    console.log(res);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
