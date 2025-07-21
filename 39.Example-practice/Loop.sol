// SPDX-License-Identifier: MIT

import "hardhat/console.sol";

pragma solidity ^0.8.20;

contract Loop {

    uint[] public myArr;

    function addArr() external {
        for (uint i = 0; i < 10; i++) {
            if (i == 3) {
                continue;
            } else if (i == 8) {
                break;
            } else {
                console.log("i",i);
                myArr.push(i);
            }
        }
    }

    function getMyArr() external view returns(uint[] memory) {
        return myArr;
    }

}