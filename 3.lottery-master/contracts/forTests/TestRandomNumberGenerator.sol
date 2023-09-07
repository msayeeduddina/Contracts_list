// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IBiswapLottery {
    function viewCurrentLotteryId() external returns (uint256);
}
contract TestRandomNumberGenerator {
    address public biswapLottery;
    uint32 public randomResult;
    uint256 public latestLotteryId;

    function getRandomNumber(uint256 _seed) external {
        require(msg.sender == biswapLottery, "Only BiswapLottery");
        uint random = uint256(keccak256(abi.encode(_seed)));
        fulfillRandomness(random);
    }

    function setLotteryAddress(address _biswapLottery) external {
        biswapLottery = _biswapLottery;
    }

    function viewLatestLotteryId() external view returns (uint256) {
        return latestLotteryId;
    }

    function viewRandomResult() external view returns (uint32) {
        return randomResult;
    }

    function fulfillRandomness(uint256 randomness) internal {
        randomResult = uint32(1000000 + (randomness % 1000000));
        latestLotteryId = IBiswapLottery(biswapLottery).viewCurrentLotteryId();
    }
}