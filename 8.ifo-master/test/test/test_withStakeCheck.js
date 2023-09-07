const { deployMockContract } = require('ethereum-waffle')
const { ethers, upgrades, network } = require('hardhat')
const { expect } = require('chai')

let accounts, owner, user1, user2, dealToken, offerToken, tokenOwner, ifo;

const toWei = n => ethers.BigNumber.from(10).pow(18).mul(n)
const numberLastBlock = async () => (await ethers.provider.getBlock('latest')).number
const timeStampLastBlock = async () => (await ethers.provider.getBlock('latest')).timestamp
const extractCost = (tx, additionalData = {}) => {
    const GAS_SPENT = +tx.gasUsed
    const GAS_PRICE = 5e9
    const WEI_PRICE = 600/1e18

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

const GAS_REPORT = {}

const STAKE_REQUIRENMENT_0 = toWei(33)
const STAKE_REQUIRENMENT_1 = toWei(66)

before(async function(){
    accounts = await ethers.getSigners()
    owner = accounts[0]
    user1 = accounts[1]
    user2 = accounts[2]
    tokenOwner = accounts[3]

    const DealToken = await ethers.getContractFactory('Token')
    dealToken   = await DealToken.deploy('Deal token',  'DTK', toWei(10000000))
    offerToken  = await DealToken.deploy('Offer token', 'OTK', toWei(10000000))
    BSW         = await DealToken.deploy('biswap token','BSW', toWei(10000000))

    await BSW.transfer(user1.address,       toWei(1000000))
    await BSW.transfer(user2.address,       toWei(1000000))
    await BSW.transfer(tokenOwner.address,  toWei(1000000))

    await dealToken.transfer(user1.address,     toWei(1000000))
    await dealToken.transfer(user2.address,     toWei(1000000))
    await dealToken.transfer(tokenOwner.address,toWei(1000000))

    const MasterChef = await ethers.getContractFactory('MasterChef')
    masterChef   = await MasterChef.deploy(
        BSW.address,
        owner.address,
        owner.address,
        owner.address,
        toWei(1),
        await numberLastBlock(),
        1e6,
        0,
        0,
        0
    )

    const AutoBsw = await ethers.getContractFactory('AutoBsw')
    autoBsw = await AutoBsw.deploy(
        BSW.address,
        masterChef.address,
        owner.address,
    )
    await BSW.approve(autoBsw.address, toWei(1))
    await autoBsw.deposit(toWei(1))

    let lastBlock = await numberLastBlock()
    let startBlock = lastBlock + 10
    let finishBlock = startBlock + 1000

    const Ifo = await ethers.getContractFactory(`Contracts/IFO_withStakeCheck.sol:IFO`)
    ifo = await Ifo.deploy(
        dealToken.address,
        offerToken.address,
        startBlock,
        finishBlock,
        autoBsw.address
    )
})

describe('Check start and finish launchpad', async () => {
    let offeringAmountPool  = toWei(10000)
    let raisingAmountPool   = toWei(5000)
    let limitPerUser        = toWei(100)

    it('Must set new pools and emits events', async () => {
        await offerToken.transfer(ifo.address, toWei(30000))
        await expect(ifo.setPool(
            offeringAmountPool,
            raisingAmountPool,
            limitPerUser,
            STAKE_REQUIRENMENT_0,
            false,
            0
        ), 'set pool one').emit(ifo, 'PoolParametersSet')
        await expect(ifo.setPool(
            offeringAmountPool.mul(2),
            raisingAmountPool.mul(2),
            0,
            STAKE_REQUIRENMENT_1,
            false,
            1
        ), 'set pool two').emit(ifo, 'PoolParametersSet')
    })

    it('Must not be able before start', async () => {
        await dealToken.transfer(user1.address, toWei(1e6))
        await dealToken.connect(user1).approve(ifo.address, toWei(10e6))
        await expect(ifo.connect(user1).depositPool(toWei(10), 0)).revertedWith('Too early')
        let currentBlock = await numberLastBlock()
        let startBlock = await ifo.startBlock()

        while(currentBlock < startBlock){
            await network.provider.send('evm_mine')
            currentBlock = await numberLastBlock()
        }

        await BSW.connect(user1).approve(autoBsw.address, toWei(10000000))
        await expect(ifo.connect(user1).depositPool(toWei(10), 0)).revertedWith('Not enough BSW in long term staking pool')
        await autoBsw.connect(user1).deposit(toWei(1))
        while(true){
            const totalRewards  = +(await autoBsw.balanceOf()) / 1e18
            const userShares    = +(await autoBsw.userInfo(user1.address)).shares / 1e18
            const totalShares   = +(await autoBsw.totalShares()) /1e18

            BSW_balance = totalRewards * userShares / totalShares
            console.log(`${totalRewards} * ${userShares} / ${totalShares} = ${BSW_balance}`)
            if(BSW_balance >= 66) break
            await autoBsw.connect(user1).deposit(toWei(1))
        }

        await expect(ifo.connect(user1).depositPool(toWei(10), 0)).emit(ifo, 'Deposit')
    })

    it('Must return correct offering and refunding amounts for pools', async () => {

        let amountPools = await ifo.viewUserOfferingAndRefundingAmountsForPools(user1.address)
        expect(amountPools,'1').eql([
            [toWei(20),     toWei(0),       toWei(0)],
            [toWei(0),      toWei(0),       toWei(0)]
        ])

        //deposit to pid 2
        await expect(ifo.connect(user1).depositPool(toWei(5000), 1),'2').emit(ifo, 'Deposit')
        expect(await ifo.viewUserOfferingAndRefundingAmountsForPools(user1.address),'3').eql([
            [toWei(20),     toWei(0),       toWei(0)],
            [toWei(10000),  toWei(0),       toWei(0)]
        ])

        //deposit overlimit pid2
        await expect(ifo.connect(user1).depositPool(toWei(6000), 1),'4').emit(ifo, 'Deposit')
        expect((await ifo.viewUserOfferingAndRefundingAmountsForPools(user1.address)),'5').eql([
            [toWei(20),     toWei(0),       toWei(0)],
            [toWei(20000),  toWei(1000),    toWei(0)]
        ])

        //deposit from user2
        await BSW.connect(user2).approve(autoBsw.address, toWei(10e6))
        await autoBsw.connect(user2).deposit(toWei(100))
        await dealToken.transfer(user2.address, toWei(1e6))
        await dealToken.connect(user2).approve(ifo.address, toWei(10e6))
        await expect(ifo.connect(user2).depositPool(toWei(5000), 1),'6').emit(ifo, 'Deposit')

        expect((await ifo.viewUserOfferingAndRefundingAmountsForPools(user1.address)),'7').eql([
            [toWei(20),     toWei(0),       toWei(0)],
            [toWei(13750),  toWei(4125),    toWei(0)]
        ])

        expect((await ifo.viewUserOfferingAndRefundingAmountsForPools(user2.address)),'8').eql([
            [toWei(0),      toWei(0),       toWei(0)],
            [toWei(6250),   toWei(1875),    toWei(0)]
        ])
    })

    it('Must revert when try to deposit over limit on pool', async () => {
        await expect(ifo.connect(user1).depositPool(toWei(91),0)).revertedWith('New amount above user limit')
        await expect(ifo.connect(user1).depositPool(toWei(90),0)).emit(ifo, 'Deposit')
    })

    it('Should not give make harvest while time not over', async () => {
        await expect(ifo.connect(user1).harvestPool(0)).revertedWith('Too early to harvest')
    })

    it('Should correct harvest pool when show time', async () => {
        let currentBlock = await numberLastBlock()
        let endBlock = await ifo.endBlock()
        while(currentBlock <= endBlock){
            await network.provider.send('evm_mine')
            currentBlock = await numberLastBlock()
        }
        await expect(ifo.connect(user1).harvestAllPools()).emit(ifo ,'Harvest')
        expect(await offerToken.balanceOf(user1.address)).eq(toWei(13950))

        await expect(ifo.connect(user2).harvestAllPools()).emit(ifo, 'Harvest')
        expect(await offerToken.balanceOf(user2.address)).eq(toWei(6250))
    })

    it(`Should use STAKE CHECK`, async () => {




    })
})
