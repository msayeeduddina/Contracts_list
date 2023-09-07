// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Council <council@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity >=0.6.0 <0.9.0;

/// @title IMapleV1MplRewards Interface
/// @author Enzyme Council <security@enzyme.finance>
interface IMapleV1MplRewards {
    function getReward() external;

    function rewardsToken() external view returns (address);
}
