// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract ArrayHashingExample {
    // Fixed-size array
    uint256[4] public fixedSizeArray = [1, 2, 3, 4];
    bytes32 public fixedSizeArrayHash;

    // Dynamic array
    uint256[] public dynamicArray = [1, 2, 3, 4];
    bytes32 public dynamicArrayHash;

    constructor() {
        // Hash the fixed-size array
        fixedSizeArrayHash = keccak256(abi.encodePacked(fixedSizeArray));

        // Hash the dynamic array (not recommended)
        // This will only hash the length and data location, not the elements
        dynamicArrayHash = keccak256(abi.encodePacked(dynamicArray));
    }

    // Function to hash a dynamic array using a loop
    function hashDynamicArrayWithLoop() external view returns (bytes32) {
        bytes memory concatenatedBytes;
        for (uint256 i = 0; i < dynamicArray.length; i++) {
            concatenatedBytes = abi.encodePacked(concatenatedBytes, dynamicArray[i]);
        }
        return keccak256(concatenatedBytes);
    }

    function hashDynamicArrayWithoutLoop() external view returns (bytes32) {
        return bytes32(abi.encodePacked(dynamicArray));
    }

    // Function to retrieve the hash of the fixed-size array
    function getFixedSizeArrayHash() external view returns (bytes32) {
        return fixedSizeArrayHash;
    }

    // Function to retrieve the hash of the dynamic array
    function getDynamicArrayHash() external view returns (bytes32) {
        return dynamicArrayHash;
    }
}
