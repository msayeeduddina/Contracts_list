// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract MultiDelegateCall {
    error DelegateCallIssue();

    function multiDelegateCall(bytes[] memory data) external payable returns (bytes[] memory result) {
        result = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory res) = address(this).delegatecall(data[i]);
            if (!success) {
                revert DelegateCallIssue();
            }
            result[i] = res;
        }
    }
}

contract TestMultiDelegateCall is MultiDelegateCall {
    mapping(address=>uint) public balanceOf;
    event Log(address indexed caller, string functionName, uint256 result);

    function func1(uint256 x, uint256 y) external {
        emit Log(msg.sender, "func1", x + y);
    }

    function func2() external returns (uint256) {
        emit Log(msg.sender, "func2", 2);
        return 111;
    }

    function mint() external payable {
        balanceOf[msg.sender] += msg.value;
    }
}

contract Helper {
    function getSignatureFunc1(uint256 x, uint256 y) external pure returns (bytes memory) {
        return abi.encodeWithSelector(TestMultiDelegateCall.func1.selector, x, y);
    }

    function getSignatureFunc2() external pure returns (bytes memory) {
        return abi.encodeWithSelector(TestMultiDelegateCall.func2.selector);
    }

    function getSignatureMint() external pure returns (bytes memory) {
        return abi.encodeWithSelector(TestMultiDelegateCall.mint.selector);
    }

}
