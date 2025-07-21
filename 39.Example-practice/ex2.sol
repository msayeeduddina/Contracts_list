// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract One{
    function getValue() public pure virtual returns(uint){
        return 10;
    }
}
contract Two{
    function getValue() public pure virtual  returns(uint){
        return 20;
    }
}
contract Three{
    function getValue() public pure virtual returns(uint){
        return 30;
    }
}
contract Four is One,Two,Three{

    function getValue() public pure override (One,Two,Three) returns(uint){
       return super.getValue();
    }

}