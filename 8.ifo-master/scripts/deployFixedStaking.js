const { ethers, upgrades, network } = require('hardhat')

const WBNB_ADDRESS       = '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c'
const ADA_ADDRESS       = `0x3ee2200efb3400fabb9aacf31297cbdd1d435d47`
const DOT_ADDRESS       = `0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402`
const AUTOBSW_ADDRESS   = '0xa4b20183039b2F9881621C3A03732fBF0bfdff10'

const TREASURY_ADDRESS  = '0x4b83b646761325ff71874719f64A8c5221Bed9a0'
const TREASURY_ADMIN_ADDRESS  = '0x5748e67AD615D0494C0fFaedB26843Af8065C4cC'

const FIXED_STAKING_ADDRESS = `0xa04adebaf9c96882C6d59281C23Df95AF710003e`

const toBN = (numb, power = 18) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

let fixedStaking, nonce, accounts, deployer

const main = async () => {
    accounts = await ethers.getSigners()
    deployer = accounts[0]
    nonce = await network.provider.send('eth_getTransactionCount', [deployer.address, 'latest']) -1

    console.log('\n' + '='.repeat(80))
    console.log(`[👤] deployer:\t${deployer.address}`)
    console.log(`[🌐] network:\t${network.name}`)
    console.log(`[🔗] chainId:\t${network.config.chainId}`)
    console.log(`[💵] gasPrice:\t${network.config.gasPrice}`)
    console.log('='.repeat(80)+'\n')

    const FixedStakingFactory = await ethers.getContractFactory('FixedStaking')
    // fixedStaking = await upgrades.deployProxy(
    //     FixedStakingFactory,
    //     [TREASURY_ADDRESS, TREASURY_ADMIN_ADDRESS,  AUTOBSW_ADDRESS],
    //     {nonce: ++nonce, gasLimit: 5e6
    //     }
    // )
    // await fixedStaking.deployed() && nonce++
    // console.log(`✅ fixedStaking deployed to: ${fixedStaking.address}`)
    fixedStaking = await FixedStakingFactory.attach(FIXED_STAKING_ADDRESS);

    const endDayForPools = +await fixedStaking.getCurrentDay() + 360
    const pools = [{
            token:                  WBNB_ADDRESS,//token
            endDay:                 endDayForPools,
            dayPercent:             138082,            //one day percent in Base 1000000
            lockPeriod:             30,             //lock period in days
            withdrawalFee:          199,           //early withdrawal fee in base 10000
            maxDeposit:             toBN(425,17),    //maxDeposit;
            minDeposit:             toBN(2),     //minDeposit;
            holderPoolMinAmount:    toBN(200),     //holder pool amount
            totalDeposited:         0,              //totalDeposited;
            maxPoolAmount:          toBN(2125),     //maxPoolAmount;
            depositEnabled:         true           //depositEnabled;
        },
        {
            token:                  WBNB_ADDRESS,//token
            endDay:                 endDayForPools,
            dayPercent:             167945,            //one day percent in Base 1000000
            lockPeriod:             60,             //lock period in days
            withdrawalFee:          199,           //early withdrawal fee in base 10000
            maxDeposit:             toBN(10),    //maxDeposit;
            minDeposit:             toBN(15,17),     //minDeposit;
            holderPoolMinAmount:    toBN(300),     //holder pool amount
            totalDeposited:         0,              //totalDeposited;
            maxPoolAmount:          toBN(250),     //maxPoolAmount;
            depositEnabled:         true           //depositEnabled;

        },
        {
            token:                  WBNB_ADDRESS,//token
            endDay:                 endDayForPools,
            dayPercent:             276986,            //one day percent in Base 1000000
            lockPeriod:             90,             //lock period in days
            withdrawalFee:          199,           //early withdrawal fee in base 10000
            maxDeposit:             toBN(25,17),    //maxDeposit;
            minDeposit:             toBN(1),     //minDeposit;
            holderPoolMinAmount:    toBN(400),     //holder pool amount
            totalDeposited:         0,              //totalDeposited;
            maxPoolAmount:          toBN(125),     //maxPoolAmount;
            depositEnabled:         true           //depositEnabled;

        },
        {
            token:                  ADA_ADDRESS,//token
            endDay:                 endDayForPools,
            dayPercent:             181095,            //one day percent in Base 1000000
            lockPeriod:             30,             //lock period in days
            withdrawalFee:          199,           //early withdrawal fee in base 10000
            maxDeposit:             toBN(9125),    //maxDeposit;
            minDeposit:             toBN(600),     //minDeposit;
            holderPoolMinAmount:    toBN(200),     //holder pool amount
            totalDeposited:         0,              //totalDeposited;
            maxPoolAmount:          toBN(365000),     //maxPoolAmount;
            depositEnabled:         true           //depositEnabled;

        },
        {
            token:                  ADA_ADDRESS,//token
            endDay:                 endDayForPools,
            dayPercent:             209589,            //one day percent in Base 1000000
            lockPeriod:             60,             //lock period in days
            withdrawalFee:          199,           //early withdrawal fee in base 10000
            maxDeposit:             toBN(2150),    //maxDeposit;
            minDeposit:             toBN(450),     //minDeposit;
            holderPoolMinAmount:    toBN(300),     //holder pool amount
            totalDeposited:         0,              //totalDeposited;
            maxPoolAmount:          toBN(43000),     //maxPoolAmount;
            depositEnabled:         true           //depositEnabled;

        },
        {
            token:                  ADA_ADDRESS,//token
            endDay:                 endDayForPools,
            dayPercent:             329589,            //one day percent in Base 1000000
            lockPeriod:             90,             //lock period in days
            withdrawalFee:          199,           //early withdrawal fee in base 10000
            maxDeposit:             toBN(860),    //maxDeposit;
            minDeposit:             toBN(300),     //minDeposit;
            holderPoolMinAmount:    toBN(400),     //holder pool amount
            totalDeposited:         0,              //totalDeposited;
            maxPoolAmount:          toBN(21500),     //maxPoolAmount;
            depositEnabled:         true           //depositEnabled;

        },
        {
            token:                  DOT_ADDRESS,//token
            endDay:                 endDayForPools,
            dayPercent:             283835,            //one day percent in Base 1000000
            lockPeriod:             30,             //lock period in days
            withdrawalFee:          199,           //early withdrawal fee in base 10000
            maxDeposit:             toBN(391),    //maxDeposit;
            minDeposit:             toBN(20),     //minDeposit;
            holderPoolMinAmount:    toBN(200),     //holder pool amount
            totalDeposited:         0,              //totalDeposited;
            maxPoolAmount:          toBN(19550),     //maxPoolAmount;
            depositEnabled:         true           //depositEnabled;

        },
        {
            token:                  DOT_ADDRESS,//token
            endDay:                 endDayForPools,
            dayPercent:             342739,            //one day percent in Base 1000000
            lockPeriod:             60,             //lock period in days
            withdrawalFee:          199,           //early withdrawal fee in base 10000
            maxDeposit:             toBN(92),    //maxDeposit;
            minDeposit:             toBN(15),     //minDeposit;
            holderPoolMinAmount:    toBN(300),     //holder pool amount
            totalDeposited:         0,              //totalDeposited;
            maxPoolAmount:          toBN(2300),     //maxPoolAmount;
            depositEnabled:         true           //depositEnabled;

        },
        {
            token:                  DOT_ADDRESS,//token
            endDay:                 endDayForPools,
            dayPercent:             496438,            //one day percent in Base 1000000
            lockPeriod:             90,             //lock period in days
            withdrawalFee:          199,           //early withdrawal fee in base 10000
            maxDeposit:             toBN(2875,16),    //maxDeposit;
            minDeposit:             toBN(10),     //minDeposit;
            holderPoolMinAmount:    toBN(400),     //holder pool amount
            totalDeposited:         0,              //totalDeposited;
            maxPoolAmount:          toBN(1150),     //maxPoolAmount;
            depositEnabled:         true           //depositEnabled;

        }
    ]

    for(let item of pools){
        await addPool(item);
    }

    console.log(`💕 DONE 💕`)
}

const addPool = async _pool => {
    const tx = await fixedStaking.addPool(_pool, {nonce: ++nonce, gasLimit: 3e6})
    await tx.wait()
    console.log(`\t✅ pool for '${_pool.token.slice(0,8)}...' added`)
}

const changePool = async (index, _pool) => {
    const tx = await fixedStaking.changePool(index, _pool, {nonce: ++nonce, gasLimit: 1e6})
    await tx.wait()
    console.log(`\t✅ pool #${index} for '${_pool.token.slice(0,8)}...' changed`)
}

main()
    .then(() => process.exit(0))
    .catch(err => console.error(err) && process.exit(1))
