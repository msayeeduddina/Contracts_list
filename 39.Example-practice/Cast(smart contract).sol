pragma solidity ^0.8.3;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IInstaIndex {
    function build(
        address _owner,
        uint256 _accountVersion,
        address _origin
    ) external returns (address _account);
}

interface IDSA {
    function cast(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        address _origin
    ) external payable returns (bytes32);
}

contract InteractingDSA {

    IInstaIndex instaIndex = IInstaIndex(0x2971adfa57b20e5a416ae5a708a8655a9c74f723); // this address is only of mainnet.

    function buildAndCast(address _owner) external {
        // creating an account
        address _account = instaIndex.build(_owner, 2, address(0)); // 2 is the most recent DSA version
        
        // encoding data to run multiple things through cast on account
        // Depositing in DSA and then deposit in Compound through DSA.
        string[] memory _targets = new string[](2);
        bytes[] memory _data = new bytes[](2);
        
        _targets[0] = "BASIC-A";
        _targets[1] = "COMPOUND-A";
        
        bytes4 memory basicDeposit = bytes4(keccak256("deposit(address,uint256,uint256,uint256)"));
        bytes4 memory compoundDeposit = bytes4(keccak256("deposit(string,uint256,uint256,uint256)"));
        
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        uint amtToDeposit = 1e18; // 1 DAI
        
        _data[0] = abi.encodeWithSelector(basicDeposit, dai, amtToDeposit, 0, 0);
        _data[1] = abi.encodeWithSelector(compoundDeposit, "DAI-A", amtToDeposit, 0, 0);
        
        IDSA(_account).cast(_targets, _data, address(0)); // Magic!!
    }

}   
