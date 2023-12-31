const Nmx = artifacts.require("Nmx");
const MockedStakingToken = artifacts.require("MockedStakingToken");
const MockedUsdtToken = artifacts.require("MockedUsdtToken");
const StakingRouter = artifacts.require("StakingRouter");
const StakingService2 = artifacts.require("StakingService2");
const { rpcCommand, getAssertBN } = require("../utils.js");
const truffleAssert = require("truffle-assertions");
const { step } = require("mocha-steps");

const toBN = web3.utils.toBN;
const toWei = web3.utils.toWei;
const fromWei = web3.utils.fromWei;

contract("StakingService2; Group: Staking", (accounts) => {
  const assertBN = getAssertBN(0);

  let nmx;
  let stakingToken;
  let stakingService;
  let snapshotId;
  let stakingRouter;

  let errorMessage = "";
  let tx = null;

  before(async () => {
    nmx = await Nmx.deployed();

    let usdtToken = await MockedUsdtToken.new();
    stakingToken = await MockedStakingToken.new(usdtToken.address);

    stakingRouter = await StakingRouter.new(nmx.address);
    nmx.transferPoolOwnership(1, stakingRouter.address);

    stakingService = await StakingService2.new(
      nmx.address,
      stakingToken.address,
      stakingRouter.address
    );
    stakingRouter.changeStakingServiceShares(
      new Array(stakingService.address),
      new Array(1).fill(1)
    );

    await stakingToken.transfer(accounts[1], toWei(toBN(1000)));
    await stakingToken.approve(stakingService.address, toWei(toBN(500)), {
      from: accounts[1],
    });
    await stakingToken.transfer(accounts[3], toWei(toBN(100)));
    await stakingToken.approve(stakingService.address, toWei(toBN(50)), {
      from: accounts[3],
    });
    await stakingToken.transfer(accounts[4], toWei(toBN(50)));
    await stakingToken.approve(stakingService.address, toWei(toBN(100)), {
      from: accounts[4],
    });
  });

  function makeSuite(name, tests) {
    describe(`Test: ${name}`, function () {
      before(async () => {
        // snaphot must be taken before each test because of the issue in ganache
        // evm_revert also deletes the saved snapshot
        // https://github.com/trufflesuite/ganache-cli/issues/138
        snapshotId = await rpcCommand("evm_snapshot");
        //await verifyStakedAmount(0); TODO
      });
      tests();
      after(async () => {
        await rpcCommand("evm_revert", [snapshotId]);
        errorMessage = "";
        tx = null;
      });
    });
  }

  makeSuite("Successful stake for user", () => {
    verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
    stake(10, accounts[1]);
    errorNotOccurred();
    checkStakedEventEmitted(accounts[1], 10);
    verifyUserBalanceAndStakedAmount(accounts[1], 990, 10);
    verifyStakingServiceBalanceAndTotalStaked(10);
  });

  makeSuite("User can stake multiple times", () => {
    stake(30, accounts[1]);
    stake(20, accounts[1]);
    errorNotOccurred();
    checkStakedEventEmitted(accounts[1], 20);
    verifyUserBalanceAndStakedAmount(accounts[1], 950, 50);
    verifyStakingServiceBalanceAndTotalStaked(50);
  });

  makeSuite("Staking is not available when StakingService2 paused", () => {
    pauseStakingService();
    stake(15, accounts[1]);
    checkErrorOccurred("Pausable: paused");
    checkStakingEventNotEmitted("Staked");
    verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
  });

  makeSuite(
    "Staking is available when StakingService2 unpaused after pause",
    () => {
      pauseStakingService();
      unpauseStakingService();
      stake(3, accounts[1]);
      errorNotOccurred();
      checkStakedEventEmitted(accounts[1], 3);
      verifyUserBalanceAndStakedAmount(accounts[1], 997, 3);
      verifyStakingServiceBalanceAndTotalStaked(3);
    }
  );

  makeSuite("Error occurred when user stake more than approved", () => {
    stake(501, accounts[1]);
    checkErrorOccurred("ERC20: transfer amount exceeds allowance");
    checkStakingEventNotEmitted("Staked");
    verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
  });

  makeSuite("Error occurred when user stake more than balance", () => {
    verifyUserBalanceAndStakedAmount(accounts[4], 50, 0);
    stake(51, accounts[4]);
    checkErrorOccurred("ERC20: transfer amount exceeds balance");
    checkStakingEventNotEmitted("Staked");
    verifyUserBalanceAndStakedAmount(accounts[4], 50, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
  });

  makeSuite("User can stake 0 amount", () => {
    stake(0, accounts[1]);
    errorNotOccurred();
    checkStakedEventEmitted(accounts[1], 0);
    verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
  });

  makeSuite("Error occurred when user stake negative amount", () => {
    stake(-1, accounts[1]);
    checkErrorOccurred("INVALID_ARGUMENT");
    checkStakingEventNotEmitted("Staked");
    verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
  });

  makeSuite("TotalStaked accumulate all users staked amount", () => {
    stake(4, accounts[1]);
    stake(5, accounts[3]);
    stake(1, accounts[4]);
    verifyStakingServiceBalanceAndTotalStaked(10);
  });

  makeSuite("User can stake after unstaking", () => {
    stake(30, accounts[1]);
    unstake(10, accounts[1]);
    stake(5, accounts[1]);
    errorNotOccurred();
    checkStakedEventEmitted(accounts[1], 5);
    verifyUserBalanceAndStakedAmount(accounts[1], 975, 25);
    verifyStakingServiceBalanceAndTotalStaked(25);
  });

  makeSuite("Successful unstake for user", () => {
    stake(20, accounts[1]);
    unstake(20, accounts[1]);
    errorNotOccurred();
    checkUnstakedEventEmitted(accounts[1], accounts[1], 20);
    verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
  });

  makeSuite("User can unstake in multiple steps", () => {
    stake(20, accounts[1]);
    unstake(7, accounts[1]);
    errorNotOccurred();
    checkUnstakedEventEmitted(accounts[1], accounts[1], 7);
    verifyUserBalanceAndStakedAmount(accounts[1], 987, 13);
    verifyStakingServiceBalanceAndTotalStaked(13);
    unstake(13, accounts[1]);
    errorNotOccurred();
    checkUnstakedEventEmitted(accounts[1], accounts[1], 13);
    verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
  });

  makeSuite("Unstaking is available when StakingService2 paused", () => {
    stake(20, accounts[1]);
    pauseStakingService();
    unstake(15, accounts[1]);
    errorNotOccurred();
    checkUnstakedEventEmitted(accounts[1], accounts[1], 15);
    verifyUserBalanceAndStakedAmount(accounts[1], 995, 5);
    verifyStakingServiceBalanceAndTotalStaked(5);
  });

  makeSuite("Error occurred when user unstake without staking", () => {
    unstake(15, accounts[1]);
    checkErrorOccurred("NmxStakingService: NOT_ENOUGH_STAKED");
    checkStakingEventNotEmitted("Unstaked");
    verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
  });

  makeSuite("Error occurred when user unstake more than staked", () => {
    stake(20, accounts[1]);
    unstake(21, accounts[1]);
    checkErrorOccurred("NmxStakingService: NOT_ENOUGH_STAKED");
    checkStakingEventNotEmitted("Unstaked");
    verifyUserBalanceAndStakedAmount(accounts[1], 980, 20);
    verifyStakingServiceBalanceAndTotalStaked(20);
  });

  makeSuite("User can unstake 0 amount", () => {
    stake(20, accounts[1]);
    unstake(0, accounts[1]);
    errorNotOccurred();
    checkUnstakedEventEmitted(accounts[1], accounts[1], 0);
    verifyUserBalanceAndStakedAmount(accounts[1], 980, 20);
    verifyStakingServiceBalanceAndTotalStaked(20);
  });

  makeSuite("Error occurred when user unstake negative amount", () => {
    stake(5, accounts[1]);
    unstake(-1, accounts[1]);
    checkErrorOccurred("INVALID_ARGUMENT");
    checkStakingEventNotEmitted("Staked");
    verifyUserBalanceAndStakedAmount(accounts[1], 995, 5);
    verifyStakingServiceBalanceAndTotalStaked(5);
  });

  makeSuite("TotalStaked accumulate users unstaked amount", () => {
    stake(14, accounts[1]);
    stake(15, accounts[3]);
    stake(11, accounts[4]);
    unstake(4, accounts[1]);
    unstake(5, accounts[3]);
    unstake(1, accounts[4]);
    verifyStakingServiceBalanceAndTotalStaked(30);
  });

  makeSuite("User can stake for yourself with using stakeFrom", () => {
    stakeFrom(5, accounts[1], accounts[1]);
    errorNotOccurred();
    checkStakedEventEmitted(accounts[1], 5);
    verifyUserBalanceAndStakedAmount(accounts[1], 995, 5);
    verifyStakingServiceBalanceAndTotalStaked(5);
  });

  makeSuite("Other user can stake if approved balance is enough", () => {
    verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
    verifyUserBalanceAndStakedAmount(accounts[3], 100, 0);
    stakeFrom(5, accounts[1], accounts[3]);
    errorNotOccurred();
    checkStakedEventEmitted(accounts[1], 5);
    verifyUserBalanceAndStakedAmount(accounts[1], 995, 5);
    verifyUserBalanceAndStakedAmount(accounts[3], 100, 0);
    verifyStakingServiceBalanceAndTotalStaked(5);
  });

  makeSuite(
    "Other user can stake multiple times if approved balance is enough",
    () => {
      stakeFrom(5, accounts[1], accounts[3]);
      stakeFrom(10, accounts[1], accounts[3]);
      errorNotOccurred();
      checkStakedEventEmitted(accounts[1], 10);
      verifyUserBalanceAndStakedAmount(accounts[1], 985, 15);
      verifyUserBalanceAndStakedAmount(accounts[3], 100, 0);
      verifyStakingServiceBalanceAndTotalStaked(15);
    }
  );

  makeSuite("StakeFrom is not available when StakingService2 paused", () => {
    pauseStakingService();
    stakeFrom(5, accounts[1], accounts[3]);
    checkErrorOccurred("Pausable: paused");
    checkStakingEventNotEmitted("Staked");
    verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
    verifyUserBalanceAndStakedAmount(accounts[3], 100, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
  });

  makeSuite(
    "Error occurred when other user stakeFrom more than approved",
    () => {
      stakeFrom(501, accounts[1], accounts[3]);
      checkErrorOccurred("ERC20: transfer amount exceeds allowance");
      checkStakingEventNotEmitted("Staked");
      verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
      verifyUserBalanceAndStakedAmount(accounts[3], 100, 0);
      verifyStakingServiceBalanceAndTotalStaked(0);
    }
  );

  makeSuite(
    "Error occurred when other user stakeFrom more than balance",
    () => {
      verifyUserBalanceAndStakedAmount(accounts[4], 50, 0);
      stakeFrom(51, accounts[4], accounts[3]);
      checkErrorOccurred("ERC20: transfer amount exceeds balance");
      checkStakingEventNotEmitted("Staked");
      verifyUserBalanceAndStakedAmount(accounts[4], 50, 0);
      verifyUserBalanceAndStakedAmount(accounts[3], 100, 0);
      verifyStakingServiceBalanceAndTotalStaked(0);
    }
  );

  makeSuite("Other user can stakeFrom 0 amount", () => {
    stakeFrom(0, accounts[1], accounts[3]);
    errorNotOccurred();
    checkStakedEventEmitted(accounts[1], 0);
    verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
    verifyUserBalanceAndStakedAmount(accounts[3], 100, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
  });

  makeSuite("Error occurred when other user stakeFrom negative amount", () => {
    stakeFrom(-1, accounts[1], accounts[3]);
    checkErrorOccurred("INVALID_ARGUMENT");
    checkStakingEventNotEmitted("Staked");
    verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
    verifyUserBalanceAndStakedAmount(accounts[3], 100, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
  });

  makeSuite("User can unstake to yourself with using unstakeTo", () => {
    stake(20, accounts[1]);
    unstakeTo(20, accounts[1], accounts[1]);
    errorNotOccurred();
    checkUnstakedEventEmitted(accounts[1], accounts[1], 20);
    verifyUserBalanceAndStakedAmount(accounts[1], 1000, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
  });

  makeSuite("User can unstake to other address with using unstakeTo", () => {
    stake(20, accounts[1]);
    unstakeTo(20, accounts[3], accounts[1]);
    errorNotOccurred();
    checkUnstakedEventEmitted(accounts[1], accounts[3], 20);
    verifyUserBalanceAndStakedAmount(accounts[1], 980, 0);
    verifyUserBalanceAndStakedAmount(accounts[3], 120, 0);
    verifyStakingServiceBalanceAndTotalStaked(0);
  });

  makeSuite(
    "User can unstake to other address with using unstakeTo in 2 steps",
    () => {
      stake(20, accounts[1]);
      unstakeTo(12, accounts[3], accounts[1]);
      errorNotOccurred();
      checkUnstakedEventEmitted(accounts[1], accounts[3], 12);
      verifyUserBalanceAndStakedAmount(accounts[1], 980, 8);
      verifyUserBalanceAndStakedAmount(accounts[3], 112, 0);
      verifyStakingServiceBalanceAndTotalStaked(8);
      unstakeTo(8, accounts[3], accounts[1]);
      errorNotOccurred();
      checkUnstakedEventEmitted(accounts[1], accounts[3], 8);
      verifyUserBalanceAndStakedAmount(accounts[1], 980, 0);
      verifyUserBalanceAndStakedAmount(accounts[3], 120, 0);
      verifyStakingServiceBalanceAndTotalStaked(0);
    }
  );

  makeSuite(
    "User can unstake to other address with using unstakeTo when service paused",
    () => {
      stake(30, accounts[1]);
      pauseStakingService();
      unstakeTo(15, accounts[3], accounts[1]);
      errorNotOccurred();
      checkUnstakedEventEmitted(accounts[1], accounts[3], 15);
      verifyUserBalanceAndStakedAmount(accounts[1], 970, 15);
      verifyUserBalanceAndStakedAmount(accounts[3], 115, 0);
      verifyStakingServiceBalanceAndTotalStaked(15);
    }
  );

  makeSuite("Error occurred when user unstakeTo more than staked", () => {
    stake(10, accounts[1]);
    unstakeTo(11, accounts[3], accounts[1]);
    checkErrorOccurred("NmxStakingService: NOT_ENOUGH_STAKED");
    checkStakingEventNotEmitted("Unstaked");
    verifyUserBalanceAndStakedAmount(accounts[1], 990, 10);
    verifyUserBalanceAndStakedAmount(accounts[3], 100, 0);
    verifyStakingServiceBalanceAndTotalStaked(10);
  });

  makeSuite("User can unstakeTo 0 amount", () => {
    stake(10, accounts[1]);
    unstakeTo(0, accounts[3], accounts[1]);
    errorNotOccurred();
    checkUnstakedEventEmitted(accounts[1], accounts[3], 0);
    verifyUserBalanceAndStakedAmount(accounts[1], 990, 10);
    verifyUserBalanceAndStakedAmount(accounts[3], 100, 0);
    verifyStakingServiceBalanceAndTotalStaked(10);
  });

  makeSuite("Error occurred whe user unstakeTo negative amount", () => {
    stake(10, accounts[1]);
    unstakeTo(-1, accounts[3], accounts[1]);
    checkErrorOccurred("INVALID_ARGUMENT");
    checkStakingEventNotEmitted("Unstaked");
    verifyUserBalanceAndStakedAmount(accounts[1], 990, 10);
    verifyUserBalanceAndStakedAmount(accounts[3], 100, 0);
    verifyStakingServiceBalanceAndTotalStaked(10);
  });

  function stake(amountToStake, fromAddress) {
    step(`Stake ${amountToStake} from ${fromAddress}`, async () => {
      try {
        tx = await stakingService.stake(toWei(toBN(amountToStake)), {
          from: fromAddress,
        });
      } catch (error) {
        tx = null;
        errorMessage = error.message;
      }
    });
  }

  function stakeFrom(amountToStake, ownerAddress, fromAddress) {
    step(
      `StakeFrom ${amountToStake} for ${ownerAddress} from ${fromAddress}`,
      async () => {
        try {
          tx = await stakingService.stakeFrom(
            ownerAddress,
            toWei(toBN(amountToStake)),
            { from: fromAddress }
          );
        } catch (error) {
          tx = null;
          errorMessage = error.message;
        }
      }
    );
  }

  function unstake(amountToUnstake, fromAddress) {
    step(`Unstake ${amountToUnstake} from ${fromAddress}`, async () => {
      try {
        tx = await stakingService.unstake(toWei(toBN(amountToUnstake)), {
          from: fromAddress,
        });
      } catch (error) {
        tx = null;
        errorMessage = error.message;
      }
    });
  }

  function unstakeTo(amountToUnstake, toAddress, fromAddress) {
    step(
      `UnstakeTo ${amountToUnstake} to ${toAddress} from ${fromAddress}`,
      async () => {
        try {
          tx = await stakingService.unstakeTo(
            toAddress,
            toWei(toBN(amountToUnstake)),
            { from: fromAddress }
          );
        } catch (error) {
          tx = null;
          errorMessage = error.message;
        }
      }
    );
  }

  function checkErrorOccurred(expectedMessage) {
    step(
      `Check that error occurred with message "${expectedMessage}"`,
      async () => {
        await assert(errorMessage.includes(expectedMessage), errorMessage);
      }
    );
  }

  function errorNotOccurred() {
    step(`Check that error not occurred`, async () => {
      await assert.equal("", errorMessage);
    });
  }

  function checkStakedEventEmitted(staker, amount) {
    step(
      `Check "Staked" event emitted with params: owner=${staker}, amount=${amount}`,
      async () => {
        truffleAssert.eventEmitted(tx, "Staked", (ev) => {
          return (
            ev.owner === staker && fromWei(ev.amount) === amount.toString()
          );
        });
      }
    );
  }

  function checkStakingEventNotEmitted(eventName) {
    step(`Check "${eventName}" event not emitted`, async () => {
      if (tx === null) {
        return;
      }
      truffleAssert.eventNotEmitted(tx, eventName);
    });
  }

  function checkUnstakedEventEmitted(staker, to, amount) {
    step(
      `Check "Unstaked" event emitted with params: from=${staker}, to=${to}, amount=${amount}`,
      async () => {
        truffleAssert.eventEmitted(tx, "Unstaked", (ev) => {
          return (
            ev.from === staker &&
            ev.to === to &&
            fromWei(ev.amount) === amount.toString()
          );
        });
      }
    );
  }

  function verifyUserBalanceAndStakedAmount(address, balance, stakedAmount) {
    verifyUserBalance(address, balance);
    verifyUserStakedAmount(address, stakedAmount);
  }

  function verifyUserBalance(address, balance) {
    step(`User "${address}" balance is "${balance}"`, async () => {
      assertBN(
        await stakingToken.balanceOf(address),
        toWei(toBN(balance)),
        "user balance"
      );
    });
  }

  function verifyUserStakedAmount(address, stakedAmount) {
    step(`User "${address}" staked amount is "${stakedAmount}"`, async () => {
      assertBN(
        (await stakingService.stakers(address)).amount,
        stakedAmount,
        "stakedAmount"
      );
    });
  }

  function verifyStakingServiceBalanceAndTotalStaked(totalStaked) {
    verifyStakingServiceBalance(totalStaked);
    verifyTotalStaked(totalStaked);
  }

  function verifyStakingServiceBalance(balance) {
    step(`StakingService balance is "${balance}"`, async () => {
      assertBN(
        await stakingToken.balanceOf(stakingService.address),
        balance,
        "stakingService balance"
      );
    });
  }

  function verifyTotalStaked(totalStaked) {
    step(`StakingService totalStaked is "${totalStaked}"`, async () => {
      assertBN(
        (await stakingService.state()).totalStaked,
        totalStaked,
        "totalStaked"
      );
    });
  }

  function pauseStakingService() {
    step(`Pause StakingService"`, async () => {
      await stakingService.pause();
    });
  }

  function unpauseStakingService() {
    step(`Unpause StakingService"`, async () => {
      await stakingService.unpause();
    });
  }
});
