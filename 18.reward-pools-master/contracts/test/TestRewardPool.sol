// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../sdk/RewardPool.sol";

contract TestRewardPool is RewardPool(
    // reward token address
    0x5FbDB2315678afecb367f032d93F642f64180aa3, 
    // reward amount
    100, 
    // referral fee
    10, 
    // DID registry address
    0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512, 
    // credential issuer address
    0x3FBf5A6c6AA54a06D0C4AF31DDCfD02a1Aedea2e 
)
{
    function claimReward(
        address referrer
    ) external override {
        _claimReward(referrer);
    }

    function claimRewardUsingRegistryList(
        address referrer
    ) external
        requiresDIDInList("KYC")
    {
        _claimReward(referrer);
    }

    function claimRewardUsingMultipleRegistryLists(
        address referrer
    ) external
        requiresDIDInList("KYC")
        requiresDIDInList("AML")
    {
        _claimReward(referrer);
    }

    function claimRewardUsingCredential(
        address referrer,
        bytes calldata signedCredential
    ) external
        requiresValidCredential("not US resident", signedCredential)
    {
        _claimReward(referrer);
    }

    function claimRewardUsingEverything(
        address referrer,
        bytes calldata signedCredential
    ) external
        requiresDIDInList("KYC")
        requiresDIDInList("AML")
        requiresValidCredential("not US resident", signedCredential)
    {
        _claimReward(referrer);
    }
}
