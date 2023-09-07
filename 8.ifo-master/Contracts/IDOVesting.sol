// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IAutoBsw {
    function balanceOf() external view returns (uint);

    function totalShares() external view returns (uint);

    struct UserInfo {
        uint shares; // number of shares for a user
        uint lastDepositedTime; // keeps track of deposited time for potential penalty
        uint BswAtLastUserAction; // keeps track of Bsw deposited at the last user action
        uint lastUserActionTime; // keeps track of the last user action time
    }

    function userInfo(address user) external view returns (UserInfo memory);
}

/**
 * @title IDO contract with 2 pools and vending periods
 * @notice IDO contract with 2 pools and vending periods
 */
contract IDOVesting is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint8 public constant POOLS_NUMBER = 2; // Number of pools
    uint256 public constant HARVEST_PERIODS = 5; //Harvest periods

    // Struct that contains each pool characteristics
    struct Pool {
        uint256 raisingAmount; // amount of tokens raised for the pool (in deal tokens)
        uint256 offeringAmount; // amount of tokens offered for the pool (in offeringTokens)
        uint256 minLimitPerUserInDealToken; // Min limit of tokens per user (if 0, it is ignored)
        uint256 maxLimitPerUserInDealToken; // Max limit of tokens per user (if 0, it is ignored)
        uint256 totalAmount; // total amount pool deposited (in deal tokens)
        uint256 stakeRequirement; // requirements of min user stake amount
    }

    // Struct that contains each user information for both pools
    struct UserInfo {
        uint256 amount; // How many tokens the user has provided for pool
        bool[HARVEST_PERIODS] claimed; // Whether the user has claimed each period (default: false) for pool
        bool refunded; //refund excess funds
    }

    struct UserInfoFront {
        Pool[POOLS_NUMBER] pools;
        UserInfo[POOLS_NUMBER] userInfo;
        uint256[POOLS_NUMBER] userOfferingAmounts;
        uint256[POOLS_NUMBER] userRefundingAmounts;
        uint256[HARVEST_PERIODS] harvestPeriodBlocksLeft;
        uint256 userDealTokenBalance;
        uint256 autoBswAmount;
        uint256 startIDOBlock;
        uint256 endIDOBlock;
    }

    IAutoBsw public autoBsw; //holder pool contract
    IERC20Upgradeable public dealToken; // The deal token used
    IERC20Upgradeable public offeringToken; // The offering token

    Pool[POOLS_NUMBER] private _poolInfo; // Array of PoolCharacteristics of size numberPools
    uint256[HARVEST_PERIODS] public harvestReleaseBlocks; //Harvest release blocks
    uint256 public startBlock; // The block number when IDO starts
    uint256 public endBlock; // The block number when IDO ends
    uint256 public vestingBlockOffset; // Block offset between vesting distributions

    mapping(address => UserInfo[POOLS_NUMBER]) private _userInfo; // It maps the address to pool id to UserInfo

    //participators
    address[][POOLS_NUMBER] public addressList;

    event AdminWithdraw(uint256 amountDealToken, uint256 amountOfferingToken); // Admin withdraw events
    event AdminTokenRecovery(address tokenAddress, uint256 amountTokens); // Admin recovers token
    event Deposit(address indexed user, uint256 amount, uint8 indexed pid); // Deposit event
    event Harvest(
        address indexed user,
        uint256 offeringAmount,
        uint256 excessAmount,
        uint8 indexed pid,
        uint indexed harvestPeriod
    ); // Harvest event
    event NewStartAndEndBlocks(uint256 startBlock, uint256 endBlock); // Event for new start & end blocks
    event PoolParametersSet(uint8 pid); // Event when parameters are set for one of the pools

    // Modifier to prevent contracts to participate
    modifier notContract() {
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        require(msg.sender.code.length == 0, "Contract not allowed");
        _;
    }

    /**
     * @notice It initializes the contract (for proxy patterns)
     * @dev It can only be called once.
     * @param _dealToken: the deal token used
     * @param _offeringToken: the token that is offered for the IDO
     * @param _startBlock: the start block for the IDO
     * @param _endBlock: the end block for the IDO
     * @param _vestingBlockOffset: blocks between vesting periods
     * @param _autoBsw: autoBSW contract
     */
    function initialize(
        IERC20Upgradeable _dealToken,
        IERC20Upgradeable _offeringToken,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _vestingBlockOffset,
        IAutoBsw _autoBsw
    ) public initializer {
        require(_dealToken != _offeringToken, "Tokens must be different");
        require(_startBlock > block.number, "Start block must be newest than current");
        require(_endBlock > _startBlock, "End block must be newest than _startBlock");
        dealToken = _dealToken;
        offeringToken = _offeringToken;
        startBlock = _startBlock;
        endBlock = _endBlock;
        vestingBlockOffset = _vestingBlockOffset;
        autoBsw = _autoBsw;

        for (uint256 i = 0; i < HARVEST_PERIODS; i++) {
            harvestReleaseBlocks[i] = endBlock + (_vestingBlockOffset * i);
        }

        __ReentrancyGuard_init();
        __Ownable_init();
    }

    /**
     * @notice It returns Info to frontend for 1 request
     * @param user: user address (can be zero address if user not connected)
     */
    function getUserInfo(address user) external view returns (UserInfoFront memory userInfoFront) {
        userInfoFront.userInfo = _userInfo[user];
        userInfoFront.pools = _poolInfo;

        for (uint8 i = 0; i < POOLS_NUMBER; i++) {
            (userInfoFront.userOfferingAmounts[i], userInfoFront.userRefundingAmounts[i]) =
                _calculateUserAmounts(user,i);
            if (_poolInfo[i].totalAmount > _poolInfo[i].raisingAmount && userInfoFront.userInfo[i].refunded) {
                uint256 allocation = _poolInfo[i].totalAmount > 0 ? (userInfoFront.userInfo[i].amount * 1e12) / _poolInfo[i].totalAmount : 0;
                userInfoFront.userOfferingAmounts[i] = (_poolInfo[i].offeringAmount * allocation) / 1e12;
                uint256 payAmount = (_poolInfo[i].raisingAmount * allocation) / 1e12;
                userInfoFront.userRefundingAmounts[i] = userInfoFront.userInfo[i].amount - payAmount;
            }
        }

        userInfoFront.userDealTokenBalance = dealToken.balanceOf(user);
        userInfoFront.autoBswAmount = (autoBsw.balanceOf() * autoBsw.userInfo(user).shares) / autoBsw.totalShares();
        userInfoFront.startIDOBlock = startBlock;
        userInfoFront.endIDOBlock = endBlock;
            for (uint i = 0; i < HARVEST_PERIODS; i++) {
                userInfoFront.harvestPeriodBlocksLeft[i] = harvestReleaseBlocks[i] < block.number
                    ? 0
                    : harvestReleaseBlocks[i] - block.number;
            }
        return (userInfoFront);
    }

    /**
     * @notice Get participators length for pools
     */
    function getParticipatorsLength() public view returns(uint[] memory participatorsLength){
        participatorsLength = new uint[](POOLS_NUMBER);
        for(uint i = 0; i < POOLS_NUMBER; i++){
            participatorsLength[i] = addressList[i].length;
        }
    }

    /**
     * @notice It allows users to deposit deal tokens to pool
     * @param _amount: the number of deal token used (18 decimals)
     * @param _pid: pool id
     */
    function depositPool(uint256 _amount, uint8 _pid) external nonReentrant notContract {
        // Checks whether the pool id is valid
        require(_pid < POOLS_NUMBER, "Non valid pool id");

        Pool storage _pool = _poolInfo[_pid];
        UserInfo storage _user = _userInfo[msg.sender][_pid];

        // Checks limits and requirements
        require(_pool.offeringAmount > 0 && _pool.raisingAmount > 0, "Pool not set");
        require(block.number > startBlock, "Too early");
        require(block.number < endBlock, "Too late");
        require(_amount > 0, "Amount must be > 0");
        require(_checkMinStakeAmount(msg.sender, _pid), "Not enough BSW in holder pool");
        require(_user.amount + _amount >= _pool.minLimitPerUserInDealToken, "Amount is less than the minimum limit");
        require(_user.amount + _amount <= _pool.maxLimitPerUserInDealToken, "New amount above user limit");

        // Transfers funds to this contract
        dealToken.safeTransferFrom(msg.sender, address(this), _amount);

        if(_user.amount == 0){
            addressList[_pid].push(msg.sender);
        }

        // Update totalAmount and user status
        _user.amount += _amount;
        _pool.totalAmount += _amount;

        emit Deposit(msg.sender, _amount, _pid);
    }

    /**
     * @notice It allows users to harvest from pool
     * @param _pid: pool id
     * @param _harvestPeriod: harvest period
     */
    function harvestPool(uint8 _pid, uint _harvestPeriod) public nonReentrant notContract {
        require(_harvestPeriod < HARVEST_PERIODS, "harvest period out of range");
        require(_checkMinStakeAmount(msg.sender, _pid), "Not enough BSW in holder pool");
        require(block.number > harvestReleaseBlocks[_harvestPeriod], "not harvest time");
        require(_pid < POOLS_NUMBER, "Non valid pool id");
        UserInfo storage userInfoPid = _userInfo[msg.sender][_pid];
        require(userInfoPid.amount > 0, "Did not participate");
        require(!userInfoPid.claimed[_harvestPeriod], "harvest for period already claimed");

        (uint256 offeringTokenAmount, uint256 refundingTokenAmount) = _calculateUserAmounts(msg.sender, _pid);

        userInfoPid.claimed[_harvestPeriod] = true;

        // Transfer these tokens back to the user if quantity > 0
        if (refundingTokenAmount > 0 && !userInfoPid.refunded) {
            userInfoPid.refunded = true;
            dealToken.safeTransfer(msg.sender, refundingTokenAmount);
        }

        if (offeringTokenAmount > 0) {
            offeringToken.safeTransfer(msg.sender, offeringTokenAmount / HARVEST_PERIODS);
        }

        emit Harvest(msg.sender, offeringTokenAmount, refundingTokenAmount, _pid, _harvestPeriod);
    }

    /**
     * @notice It allows users to harvest from all pools and all available harvest periods
     */
    function harvestAllPools() external notContract {
        UserInfo[POOLS_NUMBER] memory userInfo = _userInfo[msg.sender];
        for (uint8 i = 0; i < POOLS_NUMBER; i++) {
            for (uint k = 0; k < HARVEST_PERIODS; k++) {
                if (userInfo[i].amount > 0 && !userInfo[i].claimed[k] && block.number > harvestReleaseBlocks[k]) {
                    harvestPool(i, k);
                }
            }
        }
    }

    /**
     * @notice It allows the admin to withdraw funds
     * @param _dealTokenAmount: the number of deal token to withdraw (18 decimals)
     * @param _offerAmount: the number of offering amount to withdraw
     * @dev This function is only callable by admin.
     */
    function finalWithdraw(uint256 _dealTokenAmount, uint256 _offerAmount) external onlyOwner {
        require(_dealTokenAmount <= dealToken.balanceOf(address(this)), "Not enough deal tokens");
        require(_offerAmount <= offeringToken.balanceOf(address(this)), "Not enough offering token");

        if (_dealTokenAmount > 0) {
            dealToken.safeTransfer(msg.sender, _dealTokenAmount);
        }

        if (_offerAmount > 0) {
            offeringToken.safeTransfer(msg.sender, _offerAmount);
        }

        emit AdminWithdraw(_dealTokenAmount, _offerAmount);
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw (18 decimals)
     * @param _tokenAmount: the number of token amount to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(dealToken), "Cannot be deal token");
        require(_tokenAddress != address(offeringToken), "Cannot be offering token");

        IERC20Upgradeable(_tokenAddress).safeTransfer(msg.sender, _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /**
     * @notice It sets parameters for pool
     * @param _pool: pool instance
     * @param _pid: pool id
     * @dev This function is only callable by owner.
     */
    function setPool(Pool calldata _pool, uint8 _pid) external onlyOwner {
        require(block.number < startBlock, "IDO has started");
        require(_pid < POOLS_NUMBER, "Pool does not exist");
        uint totalAmount = _poolInfo[_pid].totalAmount;
        _poolInfo[_pid] = _pool;
        _poolInfo[_pid].totalAmount = totalAmount;

        emit PoolParametersSet(_pid);
    }

    /**
     * @notice It allows the admin to update start and end blocks
     * @param _startBlock: the new start block
     * @param _endBlock: the new end block
     * @dev This function is only callable by admin.
     */
    function updateStartAndEndBlocks(uint256 _startBlock, uint256 _endBlock) external onlyOwner {
        require(block.number < startBlock, "IDO has started");
        require(_startBlock < _endBlock, "New startBlock must be lower than new endBlock");
        require(block.number < _startBlock, "New startBlock must be higher than current block");
        startBlock = _startBlock;
        endBlock = _endBlock;

        for (uint256 i = 0; i < HARVEST_PERIODS; i++) {
            harvestReleaseBlocks[i] = endBlock + (vestingBlockOffset * i);
        }

        emit NewStartAndEndBlocks(_startBlock, _endBlock);
    }

    /**
     * @notice Set AutoBSW contract
     * @param _autoBsw: AutoBSW contract address
     * @dev This function is only callable by admin.
     */
    function setAutoBswAddress(address _autoBsw) external onlyOwner {
        require(_autoBsw != address(0), "Cannt be zero address");
        autoBsw = IAutoBsw(_autoBsw);
    }

    /**
     * @notice Check requirements of user stake amount
     * @param _user user address
     * @param _pid pool id
     */
    function _checkMinStakeAmount(address _user, uint _pid) internal view returns (bool) {
        require(_pid < POOLS_NUMBER, "_pid out of bound");
        require(autoBsw.totalShares() > 0, "no stakes in autoBSW");
        uint autoBswBalance = (autoBsw.balanceOf() * autoBsw.userInfo(_user).shares) / autoBsw.totalShares();
        return autoBswBalance >= _poolInfo[_pid].stakeRequirement;
    }

    /**
     * @notice It calculates the offering amount for a user and the number of deal tokens to transfer back.
     * @param _user: user address
     * @param _pid: pool id
     */
    function _calculateUserAmounts(address _user, uint8 _pid)
        internal
        view
        returns (uint256 userOfferingAmount, uint256 userRefundingAmount)
    {
        Pool memory _pool = _poolInfo[_pid];
        UserInfo memory userInfo = _userInfo[_user][_pid];

        if (_pool.totalAmount > _pool.raisingAmount) {
            // Calculate allocation for the user
            //100,000,000,000 means 0.1 (10%) / 1 means 0.0000000000001 (0.0000001%) / 1,000,000,000,000 means 1 (100%)
            uint256 allocation = _pool.totalAmount > 0 ? (userInfo.amount * 1e12) / _pool.totalAmount : 0;

            // Calculate the offering amount for the user based on the offeringAmount for the pool
            userOfferingAmount = (_pool.offeringAmount * allocation) / 1e12;

            // Calculate the payAmount
            uint256 payAmount = (_pool.raisingAmount * allocation) / 1e12;

            // Calculate refunding amount
            userRefundingAmount = userInfo.refunded ? 0 : userInfo.amount - payAmount;
        } else {
            userRefundingAmount = 0;
            userOfferingAmount = (userInfo.amount * _pool.offeringAmount) / _pool.raisingAmount;
        }
        return (userOfferingAmount, userRefundingAmount);
    }
}
