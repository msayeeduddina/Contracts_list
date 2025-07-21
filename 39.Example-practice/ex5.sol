//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Test {
   address payable public richest;
   uint public mostSent;

   constructor() payable {
      richest = payable(msg.sender);
      mostSent = msg.value;
   }

   function becomeRichest() public payable returns (bool) {
      if (msg.value > mostSent) {
         richest.transfer(msg.value); // Insecure transfer
         richest = payable(msg.sender);
         mostSent = msg.value;
         return true;
      } else {
         return false;
      }
   }
}


contract TriggerWithoutRecieveorFallback {
    Test private testContract;

    constructor(address _testContract) {
        testContract = Test(_testContract);
    }

    function triggerBecomeRichest() public payable {
        testContract.becomeRichest{value: msg.value}();
    }
}

contract TriggerWithRecieveorFallback {
    Test private testContract;

    constructor(address _testContract) {
        testContract = Test(_testContract);
    }

    function triggerBecomeRichest() public payable {
        testContract.becomeRichest{value: msg.value}();
    }

    receive() external payable { }
}