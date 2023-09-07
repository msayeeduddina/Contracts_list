// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./sdk/RewardPool.sol";

contract DemoRewardPool is RewardPool(
    // TODO: set reward token address
    0x5FbDB2315678afecb367f032d93F642f64180aa3, 
    // TODO: set reward amount
    100, 
    // TODO: set referral fee
    10, 
    // TODO: set DID registry address
    0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512, 
    // TODO: set credential issuer address
    0x3FBf5A6c6AA54a06D0C4AF31DDCfD02a1Aedea2e 
)
{
    function claimReward(
        address referrer
        // TODO: uncomment next line if using credentials
        // , bytes calldata signedCredential
    ) external override
        // TODO: choose zero or more available modifiers
        // requiresDIDInList("this list")
        // requiresDIDInList("that other list")
        // requiresValidCredential("this claim", signedCredential)
    {
        _claimReward(referrer);
    }
}
