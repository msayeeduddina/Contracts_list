// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IDIDRegistry.sol";

abstract contract RewardPool {
    IDIDRegistry public didRegistry;
    mapping(string => bool) public usedDIDs;

    address public credentialIssuer;

    IERC20 public rewardToken;
    uint256 public rewardAmount;
    uint256 public referrerFee;

    event RewardClaimed(
        string indexed claimerDID,
        address indexed referrer
    );

    constructor(
        address _rewardToken,
        uint256 _rewardAmount,
        uint256 _referrerFee,
        address _didRegistry,
        address _credentialIssuer
    ) {
        rewardToken = IERC20(_rewardToken);
        rewardAmount = _rewardAmount;
        referrerFee = _referrerFee;
        didRegistry = IDIDRegistry(_didRegistry);
        credentialIssuer = _credentialIssuer;
    }

    modifier oncePerDID() {
        require(
            usedDIDs[getSenderDID()] != true,
            "Reward already redeemed"
        );

        _;

        usedDIDs[getSenderDID()] = true;
    }

    modifier requiresDID() {
        require(
            keccak256(bytes(getSenderDID())) != keccak256(bytes("")),
            "No DID found in registry"
        );
        
        _;
    }

    modifier requiresDIDInList(string memory list) {
        require(
            didRegistry.isDIDInList(getSenderDID(), list),
            string.concat("DID not found in list ", list)
        );

        _;
    }

    modifier requiresValidCredential(
        string memory claim,
        bytes calldata signedCredential
    )
    {
        require(
            ECDSA.recover(
                ECDSA.toEthSignedMessageHash(
                    abi.encodePacked(
                        claim,
                        ";",
                        getSenderDID()
                    )
                ),
                signedCredential
            ) == credentialIssuer,
            "Invalid credential"
        );

        _;
    }

    function getSenderDID()
        internal view
        returns (string memory did)
    {
        return didRegistry.getDID(msg.sender);
    }

    function _claimReward(address referrer)
        internal
        oncePerDID()
        requiresDID()
    {
        require(
            rewardToken.balanceOf(address(this)) >= rewardAmount,
            "Not enough balance"
        );

        require(
            rewardToken.transfer(msg.sender, rewardAmount - referrerFee),
            "Token transfer to claimer failed"
        );

        require(
            rewardToken.transfer(referrer, referrerFee),
            "Token transfer to referrer failed"
        );

        emit RewardClaimed(getSenderDID(), referrer);
    }

    function claimReward(address referrer) external virtual;
}
