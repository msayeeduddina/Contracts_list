//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Test4 {

    address owner;
    uint256 asset;
    bool demised;

    constructor() payable {
        owner = msg.sender;
        asset = msg.value;
        demised = false;
    }

    address[] Wallet;
    mapping(address => uint) willed;

    modifier onlyOwner() {
        require(msg.sender == owner, "u r not owner");
        _;
    }
    modifier isDemised() {
        require(demised == false, "It is already demised");
        _;
    }


    function addToWill(address wallet, uint amount) public onlyOwner {
        Wallet.push(wallet);
        willed[wallet] = amount;
    }


    function willTransfer() private isDemised {
        for (uint i = 0; i < Wallet.length; i++) {
            payable(Wallet[i]).transfer(willed[Wallet[i]]);
        }
    }

    function demise() public onlyOwner {
        willTransfer();
        demised = true;
    }

}