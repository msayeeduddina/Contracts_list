// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

abstract contract Simple {
    function Hello() public virtual returns (uint8 retVal);
}

contract Simple2 is Simple {
    function Hello() public override returns (uint8 retVal) {
        return 8;
    }
}