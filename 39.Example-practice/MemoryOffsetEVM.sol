// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract MemoryOffsetEVM {

    function test(uint testNum) external pure returns(uint data) {
        assembly {
            mstore(0x40, 0xd2)
        }
        uint8[3] memory items = [1, 2, 3];
        assembly {
            data := mload(add(0x90, 0x20))
        }
    }

}