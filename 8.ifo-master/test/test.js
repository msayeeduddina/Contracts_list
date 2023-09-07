const { expect } = require(`chai`);
const { ethers, network } = require(`hardhat`);
const {BigNumber} = require("ethers");

let accounts, owner, user1, user2, dealToken, offerToken, tokenOwner, ifo;

function expandTo18Decimals(n) {
    return (new BigNumber.from(n)).mul((new BigNumber.from(10)).pow(18))
}

async function numberLastBlock(){
    return (await ethers.provider.getBlock(`latest`)).number;
}

async function gasToCost(tx){
    let response = await tx.wait();
    let gasPrice = 0.000000005;
    let bnbPrice = 483;
    return [response.gasUsed, (gasPrice * response.gasUsed * bnbPrice).toFixed(2)];
}

before(async function(){
    accounts = await ethers.getSigners();
    owner = accounts[0];
    tokenOwner = accounts[1];
    user1 = accounts[2];
    user2 = accounts[3];

    const DealToken = await ethers.getContractFactory(`Token`);
    dealToken = await DealToken.deploy(`Deal token`, `DTK`, expandTo18Decimals(1000000));

    const OfferToken = await ethers.getContractFactory(`Token`);
    offerToken = await OfferToken.deploy(`Offer token`, `OTK`, expandTo18Decimals(1000000));

    let lastBlock = await numberLastBlock();
    let startBlock = lastBlock + 10;
    let finishBlock = startBlock + 10;

    const Ifo = await ethers.getContractFactory(`IFO`);
    ifo = await Ifo.deploy(dealToken.address, offerToken.address, startBlock, finishBlock);

})

describe(`Check start launchpad`, async function (){
    let offeringAmountPool = 10000;
    let raisingAmountPool = 5000;
    let limitPerUser = 100;

    it(`Must set new pools and emits events`, async function(){
        await offerToken.transfer(ifo.address, 30000);
        await expect(ifo.setPool(offeringAmountPool, raisingAmountPool, limitPerUser, false, 0)).to.be.emit(ifo, `PoolParametersSet`);
        await expect(ifo.setPool(offeringAmountPool*2, raisingAmountPool*2, 0, false, 1)).to.be.emit(ifo, `PoolParametersSet`);
    })

    it(`Must not be able before start`, async function (){
        await dealToken.transfer(user1.address, 1000000);
        await dealToken.connect(user1).approve(ifo.address, expandTo18Decimals(10000000));
        await expect(ifo.connect(user1).depositPool(10, 0)).to.be.revertedWith(`Too early`);
        let currentBlock = await numberLastBlock();
        let startBlock = await ifo.startBlock();

        while(currentBlock < startBlock){
            await network.provider.send("evm_mine");
            currentBlock = await numberLastBlock();
        }
        await expect(ifo.connect(user1).depositPool(10, 0)).to.be.emit(ifo, `Deposit`);
    })

    it(`Must return correct offering and refunding amounts for pools`, async function (){
        let amountPools = await ifo.viewUserOfferingAndRefundingAmountsForPools(user1.address);
        expect(amountPools.toString()).to.equal(`20,0,0,0,0,0`);

        //deposit to pid 2
        await expect(ifo.connect(user1).depositPool(5000, 1)).to.be.emit(ifo, `Deposit`);
        expect((await ifo.viewUserOfferingAndRefundingAmountsForPools(user1.address)).toString()).to.equal(`20,0,0,10000,0,0`);

        //deposit overlimit pid2
        await expect(ifo.connect(user1).depositPool(6000, 1)).to.be.emit(ifo, `Deposit`);
        expect((await ifo.viewUserOfferingAndRefundingAmountsForPools(user1.address)).toString()).to.equal(`20,0,0,20000,1000,0`);

        //deposit from user2
        await dealToken.transfer(user2.address, 1000000);
        await dealToken.connect(user2).approve(ifo.address, expandTo18Decimals(10000000));
        await expect(ifo.connect(user2).depositPool(5000, 1)).to.be.emit(ifo, `Deposit`);
        expect((await ifo.viewUserOfferingAndRefundingAmountsForPools(user1.address)).toString()).to.equal(`20,0,0,13750,4125,0`);
        expect((await ifo.viewUserOfferingAndRefundingAmountsForPools(user2.address)).toString()).to.equal(`0,0,0,6250,1875,0`);
    })

    it(`Must revert when try to deposit over limit on pool`, async function (){
        await expect(ifo.connect(user1).depositPool(91,0)).to.be.revertedWith(`New amount above user limit`);
        await expect(ifo.connect(user1).depositPool(90,0)).to.be.emit(ifo, `Deposit`);
    })

    it(`Should not give make harvest while time not over`, async function (){
        await expect(ifo.connect(user1).harvestPool(0)).to.be.revertedWith(`Too early to harvest`);
    })

    it('Should correct harvest pool when show time', async function (){
        let currentBlock = await numberLastBlock();
        let endBlock = await ifo.endBlock();
        while(currentBlock <= endBlock){
            await network.provider.send("evm_mine");
            currentBlock = await numberLastBlock();
        }
        await expect(ifo.connect(user1).harvestAllPools()).to.be.emit(ifo,`Harvest`);
        expect((await offerToken.balanceOf(user1.address)).toString()).equal(`13950`)

        await expect(ifo.connect(user2).harvestAllPools()).to.be.emit(ifo,`Harvest`);
        expect((await offerToken.balanceOf(user2.address)).toString()).equal(`6250`)
    })

    it()
})