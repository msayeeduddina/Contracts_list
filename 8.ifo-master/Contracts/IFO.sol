//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/**
 * @title IFO
 * @notice IFO model with 2 pools
 */
contract IFO is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // The deal token used
    IERC20 public dealToken;

    // The offering token
    IERC20 public offeringToken;

    // Number of pools
    uint8 public constant numberPools = 2;

    // The block number when IFO starts
    uint256 public startBlock;

    // The block number when IFO ends
    uint256 public endBlock;

    //Tax range by tax overflow given the raisingAmountPool and the totalAmountPool: totalAmountPool / raisingAmountPool
    uint256[4] public taxRange;

    //Tax percentage by each range. Index[5]: percentage from zero to first range
    //100,000,000,000 means 0.1 (10%) / 1 means 0.0000000000001 (0.0000001%) / 1,000,000,000,000 means 1 (100%)
    uint256[5] public taxPercent;

    // Array of PoolCharacteristics of size numberPools
    PoolCharacteristics[numberPools] private _poolInfo;

    // It maps the address to pool id to UserInfo
    mapping(address => mapping(uint8 => UserInfo)) private _userInfo;

    // Struct that contains each pool characteristics
    struct PoolCharacteristics {
        uint256 raisingAmountPool; // amount of tokens raised for the pool (in deal tokens)
        uint256 offeringAmountPool; // amount of tokens offered for the pool (in offeringTokens)
        uint256 limitPerUserInDealToken; // limit of tokens per user (if 0, it is ignored)
        bool hasTax; // tax on the overflow (if any, it works with _calculateTaxOverflow)
        uint256 totalAmountPool; // total amount pool deposited (in deal tokens)
        uint256 sumTaxesOverflow; // total taxes collected (starts at 0, increases with each harvest if overflow)
    }

    // Struct that contains each user information for both pools
    struct UserInfo {
        uint256 amountPool; // How many tokens the user has provided for pool
        bool claimedPool; // Whether the user has claimed (default: false) for pool
    }

    // Admin withdraw events
    event AdminWithdraw(uint256 amountDealToken, uint256 amountOfferingToken);

    // Admin recovers token
    event AdminTokenRecovery(address tokenAddress, uint256 amountTokens);

    // Deposit event
    event Deposit(address indexed user, uint256 amount, uint8 indexed pid);

    // Harvest event
    event Harvest(address indexed user, uint256 offeringAmount, uint256 excessAmount, uint8 indexed pid);

    // Event for new start & end blocks
    event NewStartAndEndBlocks(uint256 startBlock, uint256 endBlock);

    // Event when parameters are set for one of the pools
    event PoolParametersSet(uint256 offeringAmountPool, uint256 raisingAmountPool, uint8 pid);

    event NewTaxRangeAndPercents(uint256[4] _taxRange, uint256[5] _taxPercent);

    // Modifier to prevent contracts to participate
    modifier notContract() {
        require(!_isContract(msg.sender), "contract not allowed");
        require(msg.sender == tx.origin, "proxy contract not allowed");
        _;
    }

    /**
     * @notice It initializes the contract (for proxy patterns)
     * @dev It can only be called once.
     * @param _dealToken: the deal token used
     * @param _offeringToken: the token that is offered for the IFO
     * @param _startBlock: the start block for the IFO
     * @param _endBlock: the end block for the IFO
     */
    constructor(
        IERC20 _dealToken,
        IERC20 _offeringToken,
        uint256 _startBlock,
        uint256 _endBlock
    ) {
        require(_dealToken != _offeringToken, "Tokens must be different");
        require(_startBlock > block.number, "Start block must be older than current");
        require(_endBlock > _startBlock, "End block must be older than _startBlock");
        dealToken = _dealToken;
        offeringToken = _offeringToken;
        startBlock = _startBlock;
        endBlock = _endBlock;
    }

    /**
     * @notice It allows users to deposit deal tokens to pool
     * @param _amount: the number of deal token used (18 decimals)
     * @param _pid: pool id
     */
    function depositPool(uint256 _amount, uint8 _pid) external nonReentrant notContract {
        // Checks whether the pool id is valid
        require(_pid < numberPools, "Non valid pool id");

        // Checks that pool was set
        require(
            _poolInfo[_pid].offeringAmountPool > 0 && _poolInfo[_pid].raisingAmountPool > 0,
            "Pool not set"
        );

        // Checks whether the block number is not too early
        require(block.number > startBlock, "Too early");

        // Checks whether the block number is not too late
        require(block.number < endBlock, "Too late");

        // Checks that the amount deposited is not inferior to 0
        require(_amount > 0, "Amount must be > 0");

        // Transfers funds to this contract
        dealToken.safeTransferFrom(msg.sender, address(this), _amount);

        // Update the user status
        _userInfo[msg.sender][_pid].amountPool += _amount;

        // Check if the pool has a limit per user
        if (_poolInfo[_pid].limitPerUserInDealToken > 0) {
            // Checks whether the limit has been reached
            require(
                _userInfo[msg.sender][_pid].amountPool <= _poolInfo[_pid].limitPerUserInDealToken,
                "New amount above user limit"
            );
        }

        // Updates the totalAmount for pool
        _poolInfo[_pid].totalAmountPool += _amount;

        emit Deposit(msg.sender, _amount, _pid);
    }

    /**
     * @notice It allows users to harvest from pool
     * @param _pid: pool id
     */
    function harvestPool(uint8 _pid) external nonReentrant notContract {
        // Checks whether it is too early to harvest
        require(block.number > endBlock, "Too early to harvest");

        // Checks whether pool id is valid
        require(_pid < numberPools, "Non valid pool id");

        // Checks whether the user has participated
        require(_userInfo[msg.sender][_pid].amountPool > 0, "Did not participate");

        // Checks whether the user has already harvested
        require(!_userInfo[msg.sender][_pid].claimedPool, "Has harvested");

        _harvestPool(_pid);
    }

    /**
     * @notice It allows users to harvest from all pools
     */
    function harvestAllPools() external nonReentrant notContract {
        // Checks whether it is too early to harvest
        require(block.number > endBlock, "Too early to harvest");

        for(uint8 i = 0; i < numberPools; i++){
            // Checks whether the user has participated
            // Checks whether the user has already harvested
            if(_userInfo[msg.sender][i].amountPool > 0 &&
                !_userInfo[msg.sender][i].claimedPool
            ){
                _harvestPool(i);
            }
        }
    }

    /**
     * @notice It allows the admin to set tax range and percentage
     * @param _taxRange: 4 elements array with tax ranges
     * @param _taxPercent: 4 elements array with tax percentage for each tax range
     */
    function setTaxRangeAndPercents(uint256[4] calldata _taxRange, uint256[5] calldata _taxPercent) external onlyOwner {
        require(_taxRange[0] > _taxRange[1] && _taxRange[1] > _taxRange[2] && _taxRange[2] > _taxRange[3],
            "tax range must be from max to min");
        taxRange = _taxRange;
        taxPercent = _taxPercent;
        emit NewTaxRangeAndPercents(_taxRange, _taxPercent);
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

        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /**
     * @notice It sets parameters for pool
     * @param _offeringAmountPool: offering amount (in tokens)
     * @param _raisingAmountPool: raising amount (in deal tokens)
     * @param _limitPerUserInDealToken: limit per user (in deal tokens)
     * @param _hasTax: if the pool has a tax
     * @param _pid: pool id
     * @dev This function is only callable by admin.
     */
    function setPool(
        uint256 _offeringAmountPool,
        uint256 _raisingAmountPool,
        uint256 _limitPerUserInDealToken,
        bool _hasTax,
        uint8 _pid
    ) external onlyOwner {
        require(block.number < startBlock, "IFO has started");
        require(_pid < numberPools, "Pool does not exist");

        _poolInfo[_pid].offeringAmountPool = _offeringAmountPool;
        _poolInfo[_pid].raisingAmountPool = _raisingAmountPool;
        _poolInfo[_pid].limitPerUserInDealToken = _limitPerUserInDealToken;
        _poolInfo[_pid].hasTax = _hasTax;

        emit PoolParametersSet(_offeringAmountPool, _raisingAmountPool, _pid);
    }

    /**
     * @notice It allows the admin to update start and end blocks
     * @param _startBlock: the new start block
     * @param _endBlock: the new end block
     * @dev This function is only callable by admin.
     */
    function updateStartAndEndBlocks(uint256 _startBlock, uint256 _endBlock) external onlyOwner {
        require(block.number < startBlock, "IFO has started");
        require(_startBlock < _endBlock, "New startBlock must be lower than new endBlock");
        require(block.number < _startBlock, "New startBlock must be higher than current block");

        startBlock = _startBlock;
        endBlock = _endBlock;

        emit NewStartAndEndBlocks(_startBlock, _endBlock);
    }

    /**
     * @notice It returns the pool information
     * @param _pid: poolId
     * @return raisingAmountPool: amount of deal tokens raised (in deal tokens)
     * @return offeringAmountPool: amount of tokens offered for the pool (in offeringTokens)
     * @return limitPerUserInDealToken; // limit of tokens per user (if 0, it is ignored)
     * @return hasTax: tax on the overflow (if any, it works with _calculateTaxOverflow)
     * @return totalAmountPool: total amount pool deposited (in deal tokens)
     * @return sumTaxesOverflow: total taxes collected (starts at 0, increases with each harvest if overflow)
     */
    function viewPoolInformation(uint256 _pid) external view returns (
        uint256,
        uint256,
        uint256,
        bool,
        uint256,
        uint256
        )
    {
        return (
        _poolInfo[_pid].raisingAmountPool,
        _poolInfo[_pid].offeringAmountPool,
        _poolInfo[_pid].limitPerUserInDealToken,
        _poolInfo[_pid].hasTax,
        _poolInfo[_pid].totalAmountPool,
        _poolInfo[_pid].sumTaxesOverflow
        );
    }

    /**
     * @notice It returns the tax overflow rate calculated for a pool
     * @dev 100,000,000,000 means 0.1 (10%) / 1 means 0.0000000000001 (0.0000001%) / 1,000,000,000,000 means 1 (100%)
     * @param _pid: poolId
     * @return It returns the tax percentage
     */
    function viewPoolTaxRateOverflow(uint256 _pid) external view returns (uint256) {
        if (!_poolInfo[_pid].hasTax) {
            return 0;
        } else {
            return
            _calculateTaxOverflow(_poolInfo[_pid].totalAmountPool, _poolInfo[_pid].raisingAmountPool);
        }
    }

    /**
     * @notice External view function to see user allocations for both pools
     * @param _user: user address
     * @return Array of user allocations for both pools
     */
    function viewUserAllocationPools(address _user)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory allocationPools = new uint256[](numberPools);
        for (uint8 i = 0; i < numberPools; i++) {
            allocationPools[i] = _getUserAllocationPool(_user, i);
        }
        return allocationPools;
    }

    /**
     * @notice External view function to see user information
     * @param _user: user address
     */
    function viewUserInfo(address _user)
        external
        view
        returns (uint256[] memory, bool[] memory)
    {
        uint256[] memory amountPools = new uint256[](numberPools);
        bool[] memory statusPools = new bool[](numberPools);

        for (uint8 i = 0; i < numberPools; i++) {
            amountPools[i] = _userInfo[_user][i].amountPool;
            statusPools[i] = _userInfo[_user][i].claimedPool;
        }
        return (amountPools, statusPools);
    }

    /**
     * @notice External view function to see user offering and refunding amounts for both pools
     * @param _user: user address
     */
    function viewUserOfferingAndRefundingAmountsForPools(address _user)
        external
        view
        returns (uint256[3][] memory)
    {
        uint256[3][] memory amountPools = new uint256[3][](numberPools);

        for (uint8 i = 0; i < numberPools; i++) {
            uint256 userOfferingAmountPool;
            uint256 userRefundingAmountPool;
            uint256 userTaxAmountPool;

            if (_poolInfo[i].raisingAmountPool > 0) {
                (
                userOfferingAmountPool,
                userRefundingAmountPool,
                userTaxAmountPool
                ) = _calculateOfferingAndRefundingAmountsPool(_user, i);
            }

            amountPools[i] = [userOfferingAmountPool, userRefundingAmountPool, userTaxAmountPool];
        }
        return amountPools;
    }

    /**
     * @notice It calculates the tax overflow given the raisingAmountPool and the totalAmountPool.
     * @dev 100,000,000,000 means 0.1 (10%) / 1 means 0.0000000000001 (0.0000001%) / 1,000,000,000,000 means 1 (100%)
     * @return It returns the tax percentage
     */
    function _calculateTaxOverflow(uint256 _totalAmountPool, uint256 _raisingAmountPool)
        internal
        view
        returns (uint256)
    {
        uint256[4] memory _taxRange = taxRange;
        uint256 ratioOverflow = _totalAmountPool / _raisingAmountPool;

        for(uint256 i = 0; i < _taxRange.length; i++){
            if(ratioOverflow >= _taxRange[i]){
                return taxPercent[i];
            }
        }
        return taxPercent[4];
    }

    /**
     * @notice It calculates the offering amount for a user and the number of deal tokens to transfer back.
     * @param _user: user address
     * @param _pid: pool id
     * @return {uint256, uint256, uint256} It returns the offering amount, the refunding amount (in deal tokens),
     * and the tax (if any, else 0)
     */
    function _calculateOfferingAndRefundingAmountsPool(address _user, uint8 _pid)
        internal
        view
        returns (uint256, uint256, uint256)
    {
        uint256 userOfferingAmount;
        uint256 userRefundingAmount;
        uint256 taxAmount;

        if (_poolInfo[_pid].totalAmountPool > _poolInfo[_pid].raisingAmountPool) {
            // Calculate allocation for the user
            uint256 allocation = _getUserAllocationPool(_user, _pid);

            // Calculate the offering amount for the user based on the offeringAmount for the pool
            userOfferingAmount = _poolInfo[_pid].offeringAmountPool * allocation / 1e12;

            // Calculate the payAmount
            uint256 payAmount = _poolInfo[_pid].raisingAmountPool * allocation / 1e12;

            // Calculate the pre-tax refunding amount
            userRefundingAmount = _userInfo[_user][_pid].amountPool - payAmount;

            // Retrieve the tax rate
            if (_poolInfo[_pid].hasTax) {
                uint256 taxOverflow =
                _calculateTaxOverflow(
                    _poolInfo[_pid].totalAmountPool,
                    _poolInfo[_pid].raisingAmountPool
                );

                // Calculate the final taxAmount
                taxAmount = userRefundingAmount * taxOverflow / 1e12;

                // Adjust the refunding amount
                userRefundingAmount = userRefundingAmount - taxAmount;
            }
        } else {
            userRefundingAmount = 0;
            taxAmount = 0;
            // _userInfo[_user] / (raisingAmount / offeringAmount)
            userOfferingAmount = _userInfo[_user][_pid].amountPool * _poolInfo[_pid].offeringAmountPool /
                _poolInfo[_pid].raisingAmountPool;
        }
        return (userOfferingAmount, userRefundingAmount, taxAmount);
    }

    /**
     * @notice It returns the user allocation for pool
     * @dev 100,000,000,000 means 0.1 (10%) / 1 means 0.0000000000001 (0.0000001%) / 1,000,000,000,000 means 1 (100%)
     * @param _user: user address
     * @param _pid: pool id
     * @return it returns the user's share of pool
     */
    function _getUserAllocationPool(address _user, uint8 _pid) internal view returns (uint256) {
        if (_poolInfo[_pid].totalAmountPool > 0) {
            return _userInfo[_user][_pid].amountPool * 1e18 / (_poolInfo[_pid].totalAmountPool * 1e6);
        } else {
            return 0;
        }
    }

    /**
     * @notice Check if an address is a contract
     */
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    /**
     * @notice It allows to harvest from pool
     * @param _pid: pool id
     */
    function _harvestPool(uint8 _pid) private {
        // Updates the harvest status
        _userInfo[msg.sender][_pid].claimedPool = true;

        // Initialize the variables for offering, refunding user amounts, and tax amount
        uint256 offeringTokenAmount;
        uint256 refundingTokenAmount;
        uint256 userTaxOverflow;

        (offeringTokenAmount, refundingTokenAmount, userTaxOverflow) = _calculateOfferingAndRefundingAmountsPool(
            msg.sender,
            _pid
        );

        // Increment the sumTaxesOverflow
        if (userTaxOverflow > 0) {
            _poolInfo[_pid].sumTaxesOverflow += userTaxOverflow;
        }

        // Transfer these tokens back to the user if quantity > 0
        if (offeringTokenAmount > 0) {
            offeringToken.safeTransfer(msg.sender, offeringTokenAmount);
        }

        if (refundingTokenAmount > 0) {
            dealToken.safeTransfer(msg.sender, refundingTokenAmount);
        }

        emit Harvest(msg.sender, offeringTokenAmount, refundingTokenAmount, _pid);
    }
}