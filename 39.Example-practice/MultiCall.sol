//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract TimeStamp {
    function func1() public view returns(uint, uint) {
        return (1, block.timestamp);
    }

    function func2() public view returns(uint, uint) {
        return (2, block.timestamp);
    }

    function getSign1() public pure returns(bytes memory) {
        return abi.encodeWithSelector(this.func1.selector);
    }

    function getSign2() public pure returns(bytes memory) {
        return abi.encodeWithSelector(this.func2.selector);
    }
}

contract Multicalling {
    function checkMultiCall(address[] memory target, bytes[] memory data) public view returns(bytes[] memory) {
        require(target.length == data.length, "length not matched");

        bytes[] memory results = new bytes[](data.length);
        for (uint i = 0; i < target.length; i++) {
            (bool status, bytes memory result) = target[i].staticcall(data[i]);
            require(status);
            results[i] = result;
        }
        return results;
    }
}