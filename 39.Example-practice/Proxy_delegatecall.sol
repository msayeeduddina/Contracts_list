//SPDX-License-Identifier: MIT

pragma solidity ^ 0.8 .20;

contract logicV1 {
    uint public num1;
    uint public num2;

    function setNum1(uint256 _num1) external {
        num1 = _num1 * 5;
    }

    function setNum2(uint256 _num2) external {
        num2 = _num2;
    }
}

contract Proxy {

    uint public num1;
    uint public num2;
    address public owner;
    address public logicV1Contract;

    constructor(address _owner) {
        owner = _owner;
    }

    function setNum1(uint _num1) public {
        logicV1Contract.delegatecall(
            abi.encodeWithSignature("setNum1(uint256)", _num1)
        );
    }

    function setNum2(uint _num2) public {
        logicV1Contract.delegatecall(
            abi.encodeWithSignature("setNum2(uint256)", _num2)
        );
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function upgrade(address _logic) onlyOwner public {
        logicV1Contract = _logic;
    }

}