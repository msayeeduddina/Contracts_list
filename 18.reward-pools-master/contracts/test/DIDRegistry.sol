// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract DIDRegistry {
    address public root;

    mapping(address => string) private DIDForAddress;
    mapping(string => mapping(string => bool)) private lists;

    constructor() {
        root = msg.sender;
    }

    modifier requiresRoot() {
        require(
            msg.sender == root,
            "Root access required"
        );

        _;
    }

    function getDID(address addr) external view returns (string memory) {
        return DIDForAddress[addr];
    }

    function addDID(address addr, string memory DID) external requiresRoot() {
        DIDForAddress[addr] = DID;
    }

    function removeUserAddress(address addr) external requiresRoot() {
        delete DIDForAddress[addr];
    }

    function isDIDInList(string memory DID, string memory listId)
        external
        view
        returns (bool)
    {
        return lists[listId][DID];
    }

    function addDIDToList(string memory DID, string memory listId) external requiresRoot() {
        lists[listId][DID] = true;
    }

    function removeDIDFromList(string memory DID, string memory listId) external requiresRoot() {
        delete lists[listId][DID];
    }
}
