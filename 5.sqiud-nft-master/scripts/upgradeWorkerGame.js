const { ethers, upgrades} = require(`hardhat`);


const workerGameAddress = '0xF28743d962AD110d1f4C4266e5E48E94FbD85285'

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    console.log(`Start deploying upgrade Worker staff game contract`);
    const SquidWorkerGame = await ethers.getContractFactory(`SquidWorkerGame`);
    const squidWorkerGame = await upgrades.upgradeProxy(workerGameAddress, SquidWorkerGame);
    await squidWorkerGame.deployed();
    console.log(`Worker staff game upgraded`);

    console.log('Change limits');
    const weeks = [
        2747,
        2748,
        2749,
        2750,
        2751,
        2752,
        2753,
        2754,
        2755,
        2756,
        2757,
        2758,
        2759,
        2760,
        2761,
        2762,
        2763,
        2764,
        2765,
        2766,
        2767,
        2768,
        2769,
        2770,
        2771,
        2772,
        2773,
        2774,
        2775,
        2776,
        2777
    ]
    const limits = [
        11000,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0
    ]
    await squidWorkerGame.setWeeklyWorkersLimit(weeks, limits, {gasLimit: 3e6})
    console.log('Done');


}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
