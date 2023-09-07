const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

describe("RewardPool", function () {
  const initialRewardsBalance = 1000;
  const rewardAmount = 100;
  const referrerFee = 10;
  const expectedRegistryList = "KYC";
  const expectedRegistryList2 = "AML";
  const expectedClaim = "not US resident";
  const claimerDid = "did:fractal:59b9819c-c001-4e4b-aa1a-c8db6ae377cd";
  const credentialIssuer = new ethers.Wallet("7c12d9d8ff227671420b92253e9159e1cf55055415127ef13e19957d49c4d7fe"); // 0x3FBf5A6c6AA54a06D0C4AF31DDCfD02a1Aedea2e

  async function deployContractsFixture() {
    const [, claimer, referrer] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy(initialRewardsBalance);

    const DIDRegistry = await ethers.getContractFactory("DIDRegistry");
    const didRegistry = await DIDRegistry.deploy();

    const RewardPool = await ethers.getContractFactory("TestRewardPool");
    const rewardPool = await RewardPool.deploy();

    await token.transfer(rewardPool.address, initialRewardsBalance);
    
    return { token, didRegistry, rewardPool, claimer, referrer };
  }

  describe("Sanity checks", function () {
    it("_claimReward can't be called externally", async function () {
      const { rewardPool, claimer, referrer } = await loadFixture(deployContractsFixture);

      expect(rewardPool.interface.functions["_claimReward(address)"]).to.be.undefined;
      expect(rewardPool._claimReward).to.be.undefined;
    });
  });

  describe("Deployment", function () {
    it("Should set the right reward token", async function () {
      const { token, rewardPool } = await loadFixture(deployContractsFixture);

      expect(await rewardPool.rewardToken()).to.equal(token.address);
    });

    it("Should set the right reward amount", async function () {
      const { rewardPool } = await loadFixture(deployContractsFixture);

      expect(await rewardPool.rewardAmount()).to.equal(rewardAmount);
    });

    it("Should set the right referrer fee", async function () {
      const { rewardPool } = await loadFixture(deployContractsFixture);

      expect(await rewardPool.referrerFee()).to.equal(referrerFee);
    });

    it("Should set the right did registry", async function () {
      const { didRegistry, rewardPool } = await loadFixture(deployContractsFixture);

      expect(await rewardPool.didRegistry()).to.equal(didRegistry.address);
    });

    it("Should set the right credential issuer", async function () {
      const { rewardPool } = await loadFixture(deployContractsFixture);

      expect(await rewardPool.credentialIssuer()).to.equal(credentialIssuer.address);
    });
  });

  describe("Claiming rewards", function () {
    describe("In general (using a registry)", function () {
      it("Should fail if sender doesn't have a DID", async function () {
        const { rewardPool, claimer, referrer } = await loadFixture(deployContractsFixture);

        await expect(rewardPool.connect(claimer).claimReward(referrer.address)).to.be.revertedWith("No DID found in registry");
      });

      it("Should succeed if sender has a DID", async function () {
        const { token, didRegistry, rewardPool, claimer, referrer } = await loadFixture(deployContractsFixture);

        await didRegistry.addDID(claimer.address, claimerDid);

        await expect(rewardPool.connect(claimer).claimReward(referrer.address)).to.changeTokenBalances(token, [claimer, referrer], [rewardAmount - referrerFee, referrerFee]);
      });

      it("Should emit right event if it suceeds", async function () {
        const { didRegistry, rewardPool, claimer, referrer } = await loadFixture(deployContractsFixture);

        await didRegistry.addDID(claimer.address, claimerDid);

        await expect(rewardPool.connect(claimer).claimReward(referrer.address)).to.emit(rewardPool, "RewardClaimed").withArgs(claimerDid, referrer.address);
      });

      it("Should succeed at most once per DID", async function () {
        const { didRegistry, rewardPool, claimer, referrer } = await loadFixture(deployContractsFixture);

        await didRegistry.addDID(claimer.address, claimerDid);

        await rewardPool.connect(claimer).claimReward(referrer.address);

        await expect(rewardPool.connect(claimer).claimReward(referrer.address)).to.be.revertedWith("Reward already redeemed");
      });
    });

    describe("When using registry lists", function () {
      it("Should fail if sender's DID is not on the expected list", async function () {
        const { didRegistry, rewardPool, claimer, referrer } = await loadFixture(deployContractsFixture);

        await didRegistry.addDID(claimer.address, claimerDid);

        await expect(rewardPool.connect(claimer).claimRewardUsingRegistryList(referrer.address)).to.be.revertedWith(`DID not found in list ${expectedRegistryList}`);
      });

      it("Should succeed if sender's DID is on the expected list", async function () {
        const { didRegistry, rewardPool, claimer, referrer } = await loadFixture(deployContractsFixture);

        await didRegistry.addDID(claimer.address, claimerDid);
        await didRegistry.addDIDToList(claimerDid, expectedRegistryList);

        await rewardPool.connect(claimer).claimRewardUsingRegistryList(referrer.address);
      });

      it("Should work with more than one expected list", async function () {
        const { didRegistry, rewardPool, claimer, referrer } = await loadFixture(deployContractsFixture);

        await didRegistry.addDID(claimer.address, claimerDid);

        await expect(rewardPool.connect(claimer).claimRewardUsingMultipleRegistryLists(referrer.address)).to.be.revertedWith(`DID not found in list ${expectedRegistryList}`);

        await didRegistry.addDIDToList(claimerDid, expectedRegistryList);

        await expect(rewardPool.connect(claimer).claimRewardUsingMultipleRegistryLists(referrer.address)).to.be.revertedWith(`DID not found in list ${expectedRegistryList2}`);

        await didRegistry.addDIDToList(claimerDid, expectedRegistryList2);

        await rewardPool.connect(claimer).claimRewardUsingMultipleRegistryLists(referrer.address);
      });
    });

    describe("When using a credential", function () {
      it("Should fail if credential is not signed by the right issuer", async function () {
        const { didRegistry, rewardPool, claimer, referrer } = await loadFixture(deployContractsFixture);

        await didRegistry.addDID(claimer.address, claimerDid);

        const credential = claimer.signMessage(`${expectedClaim};${claimerDid}`);

        await expect(rewardPool.connect(claimer).claimRewardUsingCredential(referrer.address, credential)).to.be.revertedWith("Invalid credential");
      });

      it("Should fail if credential doesn't contain expected claim", async function () {
        const { didRegistry, rewardPool, claimer, referrer } = await loadFixture(deployContractsFixture);

        await didRegistry.addDID(claimer.address, claimerDid);

        const credential = credentialIssuer.signMessage(`unexpected claim;${claimerDid}`);

        await expect(rewardPool.connect(claimer).claimRewardUsingCredential(referrer.address, credential)).to.be.revertedWith("Invalid credential");
      });

      it("Should fail if credential doesn't contain expected DID", async function () {
        const { didRegistry, rewardPool, claimer, referrer } = await loadFixture(deployContractsFixture);

        await didRegistry.addDID(claimer.address, claimerDid);

        const credential = credentialIssuer.signMessage(`${expectedClaim};unexpected DID`);

        await expect(rewardPool.connect(claimer).claimRewardUsingCredential(referrer.address, credential)).to.be.revertedWith("Invalid credential");
      });

      it("Should succeed if credential is valid", async function () {
        const { didRegistry, rewardPool, claimer, referrer } = await loadFixture(deployContractsFixture);

        await didRegistry.addDID(claimer.address, claimerDid);

        const credential = credentialIssuer.signMessage(`${expectedClaim};${claimerDid}`);

        await rewardPool.connect(claimer).claimRewardUsingCredential(referrer.address, credential);
      });
    });

    describe("When using both a registry list and a credential", function () {
      it("Should succeed only if both check out", async function () {
        const { didRegistry, rewardPool, claimer, referrer } = await loadFixture(deployContractsFixture);

        const invalidCredential = claimer.signMessage(`claim:did`);

        await expect(rewardPool.connect(claimer).claimRewardUsingEverything(referrer.address, invalidCredential)).to.be.reverted;

        await didRegistry.addDID(claimer.address, claimerDid);

        await expect(rewardPool.connect(claimer).claimRewardUsingEverything(referrer.address, invalidCredential)).to.be.reverted;

        const validCredential = credentialIssuer.signMessage(`${expectedClaim};${claimerDid}`);

        await expect(rewardPool.connect(claimer).claimRewardUsingEverything(referrer.address, validCredential)).to.be.reverted;

        await didRegistry.addDIDToList(claimerDid, expectedRegistryList);


        await expect(rewardPool.connect(claimer).claimRewardUsingEverything(referrer.address, validCredential)).to.be.reverted;

        await didRegistry.addDIDToList(claimerDid, expectedRegistryList2);

        await expect(rewardPool.connect(claimer).claimRewardUsingEverything(referrer.address, invalidCredential)).to.be.reverted;

        await rewardPool.connect(claimer).claimRewardUsingEverything(referrer.address, validCredential);
      });
    });
  });
});
