const { expect } = require('chai')
const { ethers, upgrades, network } = require('hardhat')
const { deployMockContract } = require('ethereum-waffle')
const {
    toWei,
    toBN,
    numberLastBlock,
    timeStampLastBlock,
    extractCost,
    passTime
} = require('../testTools')

const GAS_REPORT = []

let owner, fixedStaking, pool, treasury


before( async() => {
    const accounts = await ethers.getSigners()
    owner = accounts[0]
    treasury = accounts[1]

    const Token = await ethers.getContractFactory('Token')
    USDT = await Token.deploy('USDT', 'USDT', toWei(10e6))
    BSW  = await Token.deploy('BSW',  'BSW',  toWei(30e6))

    masterChef  = await deployMockContract(owner, require('../abisForFakes/MasterChefAbi.json'))
    await masterChef.mock.userInfo.withArgs(0, owner.address).returns(toWei(0), 0)

    autoBSW     = await deployMockContract(owner, require('../abisForFakes/PoolAutoBsw.json'))
    await autoBSW.mock.userInfo.withArgs(owner.address).returns(toWei(0), 0, 0, 0)
    await autoBSW.mock.balanceOf.withArgs().returns(1)
    await autoBSW.mock.totalShares.withArgs().returns(1)

    const FixedStakingFactory = await ethers.getContractFactory('FixedStaking')
    fixedStaking = await upgrades.deployProxy(FixedStakingFactory, [treasury.address, autoBSW.address])
    await BSW.transfer(fixedStaking.address, toWei(1000))
})

describe('Check fixed staking contract', async() => {
    it('Should add pool', async() => {
        pool = {
            token:                  BSW.address,//token
            endDay:                 +await fixedStaking.getCurrentDay() - 1,
            dayPercent:             100,            //one day percent in Base 10000
            lockPeriod:             30,             //lock period in days
            withdrawalFee:          2500,           //early withdrawal fee in base 10000
            maxDeposit:             toWei(1000),    //maxDeposit;
            minDeposit:             toWei(100),     //minDeposit;
            holderPoolMinAmount:    toWei(100),     //holder pool amount
            totalDeposited:         0,              //totalDeposited;
            maxPoolAmount:          toWei(105),     //maxPoolAmount;
            depositEnabled:         false           //depositEnabled;
        }

        await fixedStaking.addPool(pool)
    })

    it('Should deposit', async() => {
        await BSW.approve(fixedStaking.address, toWei(100))
        await expect(fixedStaking.deposit(0, toWei(99))).revertedWith('Need more stake in holder pool')
        await autoBSW.mock.userInfo.withArgs(owner.address).returns(toWei(100), 0, 0, 0)
        await expect(fixedStaking.deposit(0, toWei(99))).revertedWith('Deposit on pool is disabled')
        pool.depositEnabled = true
        pool.endDay = +await fixedStaking.getCurrentDay() +120
        await fixedStaking.changePool(0, pool)
        await expect(fixedStaking.deposit(0, toWei(99))).revertedWith('Amount over pool limits')
        await expect(fixedStaking.deposit(0, toWei(106))).revertedWith('Amount over pool limits')
        pool.maxPoolAmount = toWei(10000)
        await fixedStaking.changePool(0, pool)
        await expect(fixedStaking.deposit(0, toWei(1001))).revertedWith('Amount over pool limits')

        await fixedStaking.deposit(0, toWei(100))
    })

    it('Should calculate interest', async() => {
        const userInfo = await fixedStaking.getUserInfo(owner.address)
        expect(extractInterest(userInfo)).eq(0)

        for(let i = 0; i < 30; i++){
            await passTime(86400)
            const userInfo = await fixedStaking.getUserInfo(owner.address)
            expect(extractInterest(userInfo)).eq(i+1)
        }
    })

    it('Should harvest', async() => {
        await expect(fixedStaking.harvest(0)).revertedWith('Lock period not finished')
        await passTime(86400)

        const BeforeBalance = +await BSW.balanceOf(owner.address) / 1e18
        const BeforeInterest = await extractInterest(await fixedStaking.getUserInfo(owner.address))
        await fixedStaking.harvest(0)
        const AfterBalance = +await BSW.balanceOf(owner.address) / 1e18
        const AfterInterest = await extractInterest(await fixedStaking.getUserInfo(owner.address))

        expect(BeforeBalance + BeforeInterest).eq(AfterBalance)
        expect(AfterInterest).eq(0)
    })

    it('Shoud react to additional deposit', async() => {
        await BSW.approve(fixedStaking.address, toWei(400))
        await fixedStaking.deposit(0, toWei(400))

        let interestBefore = extractInterest(await fixedStaking.getUserInfo(owner.address))
        for(let i = 0; i < 10; i++){
            await passTime(86400)
            const userInfo = await fixedStaking.getUserInfo(owner.address)
            expect(extractInterest(userInfo)).eq(interestBefore + (i+1)*5)
        }

        await BSW.approve(fixedStaking.address, toWei(250))
        await fixedStaking.deposit(0, toWei(250))

        interestBefore = extractInterest(await fixedStaking.getUserInfo(owner.address))
        for(let i = 0; i < 10; i++){
            await passTime(86400)
            const userInfo = await fixedStaking.getUserInfo(owner.address)
            expect(extractInterest(userInfo)).eq(interestBefore + (i+1)*7.5)
        }

        await BSW.approve(fixedStaking.address, toWei(250))
        await fixedStaking.deposit(0, toWei(250))

        interestBefore = extractInterest(await fixedStaking.getUserInfo(owner.address))
        for(let i = 0; i < 10; i++){
            await passTime(86400)
            const userInfo = await fixedStaking.getUserInfo(owner.address)
            expect(extractInterest(userInfo)).eq(interestBefore + (i+1)*10)
        }
    })

    it('Should withdraw', async() => {
        const deposit = 1000
        await passTime(86400*31)
        const BeforeBalance = +await BSW.balanceOf(owner.address) / 1e18
        const BeforeInterest = await extractInterest(await fixedStaking.getUserInfo(owner.address))
        await fixedStaking.withdraw(0)
        const AfterBalance = +await BSW.balanceOf(owner.address) / 1e18
        const AfterInterest = await extractInterest(await fixedStaking.getUserInfo(owner.address))

        console.log(`BeforeBalance`, BeforeBalance)
        console.log(`AfterBalance`, AfterBalance)

        expect(BeforeBalance + BeforeInterest + deposit).eq(AfterBalance)
        expect(AfterInterest).eq(0)
    })

    it('Should withdraw with fee', async() => {
        const deposit = 1000
        await BSW.approve(fixedStaking.address, toWei(deposit))
        await fixedStaking.deposit(0, toWei(deposit))

        const BeforeBalance = +await BSW.balanceOf(owner.address) / 1e18
        const BeforeInterest = await extractInterest(await fixedStaking.getUserInfo(owner.address))
        let tx = await fixedStaking.withdraw(0)
        const AfterBalance = +await BSW.balanceOf(owner.address) / 1e18
        const AfterInterest = await extractInterest(await fixedStaking.getUserInfo(owner.address))

        let res = await tx.wait()
        let event = res.events?.filter((x) => {return x.event === "Withdraw"});

        expect(BeforeBalance + deposit*0.75).eq(AfterBalance)
        expect(+await BSW.balanceOf(treasury.address)/1e18).eq(BeforeInterest + deposit*0.25)
        expect(AfterInterest).eq(0)
    })

    it('Should withdraw on last day edge', async() => {
        const deposit = 1000

        await BSW.approve(fixedStaking.address, toWei(deposit))
        await passTime((await daysToEnd() - 15 )*86400)
        await fixedStaking.deposit(0, toWei(deposit))

        let interestBefore = extractInterest(await fixedStaking.getUserInfo(owner.address))
        for(let i = 0; i < 15; i++){
            await passTime(86400)
            const userInfo = await fixedStaking.getUserInfo(owner.address)
            expect(extractInterest(userInfo)).eq(interestBefore + (i+1)*10)
        }

        const BeforeBalance = +await BSW.balanceOf(owner.address) / 1e18
        const BeforeInterest = await extractInterest(await fixedStaking.getUserInfo(owner.address))
        await fixedStaking.withdraw(0)
        const AfterBalance = +await BSW.balanceOf(owner.address) / 1e18
        const AfterInterest = await extractInterest(await fixedStaking.getUserInfo(owner.address))

        expect(Math.round(BeforeBalance + BeforeInterest + deposit)).eq(AfterBalance)
        expect(AfterInterest).eq(0)
    })

    it('Should note withdraw if not anought money', async() => {
        const deposit = 1000
        console.log(+await BSW.balanceOf(fixedStaking.address) / 1e18)
        pool.endDay = +await fixedStaking.getCurrentDay() +120
        await fixedStaking.changePool(0, pool)
        await BSW.approve(fixedStaking.address, toWei(deposit))
        await fixedStaking.deposit(0, toWei(deposit))

        let interestBefore = extractInterest(await fixedStaking.getUserInfo(owner.address))
        for(let i = 0; i < 15; i++){
            await passTime(86400)
            const userInfo = await fixedStaking.getUserInfo(owner.address)
            expect(extractInterest(userInfo)).eq(interestBefore + (i+1)*10)
        }

        await fixedStaking.connect(treasury).withdrawToken(BSW.address, await BSW.balanceOf(fixedStaking.address))
        expect(+await BSW.balanceOf(fixedStaking.address)).eq(0)

        const BeforeBalance = +await BSW.balanceOf(owner.address) / 1e18
        const BeforeInterest = await extractInterest(await fixedStaking.getUserInfo(owner.address))
        await fixedStaking.withdraw(0)
        const AfterBalance = +await BSW.balanceOf(owner.address) / 1e18
        const AfterInterest = await extractInterest(await fixedStaking.getUserInfo(owner.address))

        expect(BeforeBalance + BeforeInterest + deposit).eq(AfterBalance + AfterInterest + deposit)
        expect(+await fixedStaking.pendingWithdraw(+await fixedStaking.getCurrentDay(), BSW.address)/1e18).eq(AfterInterest + deposit)
    })
})

const extractInterest = userInfo => {
    return +userInfo[0][0].userInfo.accrueInterest/ 1e18
}

const daysToEnd = async() => {
    const info = (await fixedStaking.getUserInfo(owner.address)).info
    const lastPoolDay =     +info[0].pool.endDay
    const lastUserAction =  +info[0].userInfo.lastDayAction
    return lastPoolDay - lastUserAction
}
