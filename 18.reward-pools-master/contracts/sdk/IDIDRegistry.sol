// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IDIDRegistry {
    function getDID(address addr)
        external view
        returns (string memory did);

    function isDIDInList(string memory did, string memory list)
        external view
        returns (bool);
}
