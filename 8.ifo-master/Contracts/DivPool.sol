//SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract DivPool is Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable, AccessControlUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant INTEREST_PAYMENT_ROLE = keccak256("INTEREST_PAYMENT_ROLE");

    struct UserInfo {
        uint128 amount; //User deposit amount
        uint128 lastDepositTimestamp;
        uint128 unlockTimestamp;
    }

    struct InterestPayment {
        address token;
        uint amount;
    }

    IERC20Upgradeable public stakeToken;
    uint public totalAmount;

    uint public earlyWithdrawalFee;
    uint public feeBase;
    address public treasuryAddress;

    uint public minInitialStake;
    uint public maxStakePerUser;
    uint public lockPeriod; //Lock period in seconds

    mapping(address => UserInfo) public userInfo;


    event Deposit(address user, uint amount, uint currentUserBalance, uint totalAmount);
    event Withdraw(address user, uint amount, uint currentUserBalance, uint totalAmount);
    event EarlyWithdraw(address user, uint amount, uint fee, uint currentUserBalance, uint totalAmount);
    event InterestPayout(address user, InterestPayment[] payments);

    function initialize(
        IERC20Upgradeable _stakeToken,
        uint _earlyWithdrawalFee,
        uint _feeBase,
        uint _maxStakePerUser,
        uint _minInitialStake,
        uint _lockPeriod,
        address _treasuryAddress,
        address interestPaymentAddress
    ) public initializer {
        stakeToken = _stakeToken;
        earlyWithdrawalFee = _earlyWithdrawalFee;
        maxStakePerUser = _maxStakePerUser;
        minInitialStake = _minInitialStake;
        lockPeriod = _lockPeriod;
        feeBase = _feeBase;
        treasuryAddress = _treasuryAddress;
        __AccessControl_init_unchained();
        __ReentrancyGuard_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(INTEREST_PAYMENT_ROLE, interestPaymentAddress);
    }

    modifier notContract() {
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        require(msg.sender.code.length == 0, "Contract not allowed");
        _;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function setEarlyWithdrawalFee(uint _earlyWithdrawalFee, uint _feeBase, uint _lockPeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeBase > 0, "Value can be zero");
        earlyWithdrawalFee = _earlyWithdrawalFee;
        feeBase = _feeBase;
        lockPeriod = _lockPeriod;
    }

    function setMaxStakePerUser(uint _minInitialStake, uint _maxStakePerUser) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxStakePerUser = _maxStakePerUser;
        minInitialStake = _minInitialStake;
    }

    function setTreasuryAddress(address _treasuryAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasuryAddress != address(0), "Cant be zero address");
        treasuryAddress = _treasuryAddress;
    }

    function deposit(uint128 amount) external whenNotPaused nonReentrant notContract {
        require(amount > 0, "Amount cant be zero");
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
        UserInfo storage _userInfo = userInfo[msg.sender];
        _userInfo.amount += amount;
        require( _userInfo.amount <= maxStakePerUser, "limit per user reached");
        require(_userInfo.amount >= minInitialStake, "Balance less than minimum");
        _userInfo.unlockTimestamp = uint128(block.timestamp + lockPeriod);
        _userInfo.lastDepositTimestamp = uint128(block.timestamp);
        totalAmount += amount;
        emit Deposit(msg.sender, amount, _userInfo.amount, totalAmount);
    }

    function withdraw(uint128 amount, bool earlyWithdraw) public whenNotPaused nonReentrant notContract {
        UserInfo storage _userInfo = userInfo[msg.sender];
        require(_userInfo.amount >= amount, "Amount exceed user balance");
        if(_userInfo.amount - amount < minInitialStake){
            amount = _userInfo.amount;
        }
        _userInfo.amount -= amount;
        totalAmount -= amount;
        uint fee = 0;
        if(earlyWithdraw && _userInfo.unlockTimestamp > block.timestamp) {
            fee = amount * earlyWithdrawalFee / feeBase;
            emit EarlyWithdraw(msg.sender, amount, fee, _userInfo.amount, totalAmount);
            stakeToken.safeTransfer(treasuryAddress, fee);
        } else {
            require(_userInfo.unlockTimestamp <= block.timestamp, "Use earlyWithdraw param");
            emit Withdraw(msg.sender, amount, _userInfo.amount, totalAmount);
        }
        stakeToken.safeTransfer(msg.sender, amount - fee);
    }

    function withdrawAll(bool earlyWithdraw) external {
        uint128 withdrawAmount = userInfo[msg.sender].amount;
        withdraw(withdrawAmount, earlyWithdraw);
    }

    function harvest(address user, InterestPayment[] calldata payments) external onlyRole(INTEREST_PAYMENT_ROLE) {
        for(uint i = 0; i < payments.length; i++){
            IERC20Upgradeable(payments[i].token).transfer(user, payments[i].amount);
        }
        emit InterestPayout(user, payments);
    }

    function withdrawTokens(InterestPayment[] calldata payments, address receiver) external onlyRole(INTEREST_PAYMENT_ROLE) {
        for(uint i = 0; i < payments.length; i++){
            IERC20Upgradeable(payments[i].token).transfer(receiver, payments[i].amount);
        }
    }

    function balanceOf(address[] calldata tokens) external view returns(uint[] memory balances){
        balances = new uint[](tokens.length);
        for(uint i = 0; i < tokens.length; i++){
            balances[i] = IERC20Upgradeable(tokens[i]).balanceOf(address(this));
        }
    }

    function getUserInfo(address user) external view returns(
        UserInfo memory _userInfo,
        uint _totalAmount,
        uint _maxStakePerUser,
        uint _earlyWithdrawalFee,
        bool endLockPeriod,
        uint bswBalance
    ){
        _userInfo = userInfo[user];
        _totalAmount = totalAmount;
        _maxStakePerUser = maxStakePerUser;
        _earlyWithdrawalFee = earlyWithdrawalFee;
        endLockPeriod = _userInfo.unlockTimestamp < block.timestamp;
        bswBalance = stakeToken.balanceOf(user);
    }
}
