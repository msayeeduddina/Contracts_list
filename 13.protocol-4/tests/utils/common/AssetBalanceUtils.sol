// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SafeERC20} from "openzeppelin-solc-0.8/token/ERC20/utils/SafeERC20.sol";

import {CommonUtilsBase} from "tests/utils/bases/CommonUtilsBase.sol";
import {
    ETHEREUM_LENDING_POOL_ADDRESS as ETHEREUM_AAVE_V2_LENDING_POOL_ADDRESS,
    POLYGON_LENDING_POOL_ADDRESS as POLYGON_AAVE_V2_LENDING_POOL_ADDRESS
} from "tests/tests/protocols/aave/AaveV2Constants.sol";
import {
    ETHEREUM_POOL_ADDRESS as ETHEREUM_AAVE_V3_POOL_ADDRESS,
    POLYGON_POOL_ADDRESS as POLYGON_AAVE_V3_POOL_ADDRESS
} from "tests/tests/protocols/aave/AaveV3Constants.sol";

import {IAaveAToken} from "tests/interfaces/external/IAaveAToken.sol";
import {IAaveV2LendingPool} from "tests/interfaces/external/IAaveV2LendingPool.sol";
import {IAaveV3Pool} from "tests/interfaces/external/IAaveV3Pool.sol";
import {IERC20} from "tests/interfaces/external/IERC20.sol";
import {ILidoSteth} from "tests/interfaces/external/ILidoSteth.sol";

abstract contract AssetBalanceUtils is CommonUtilsBase {
    using SafeERC20 for IERC20;

    function increaseNativeAssetBalance(address _to, uint256 _amount) internal {
        uint256 balance = _to.balance;

        deal(_to, balance + _amount);
    }

    /// @dev The default `deal()` implementation doesn't work with rebasing tokens, tokens using storage packing for balances, etc.
    /// e.g., Aave aTokens, Lido stETH, etc. See: currently doesn't work with aTokens https://github.com/foundry-rs/forge-std/issues/140
    /// As a workaround, inheriting utils can override this function to handle the various non-standard tokens per-network.
    function increaseTokenBalance(IERC20 _token, address _to, uint256 _amount) internal {
        if (isSteth(_token)) {
            increaseStethBalance(_to, _amount);
        } else if (isAaveV2Token(_token)) {
            increaseAaveV2TokenBalance(_token, _to, _amount);
        } else if (isAaveV3Token(_token)) {
            increaseAaveV3TokenBalance(_token, _to, _amount);
        } else {
            uint256 balance = _token.balanceOf(_to);

            deal(address(_token), _to, balance + _amount);
        }
    }

    // INCREASE BALANCE HELPERS

    // Aave v2

    function getAaveV2LendingPoolAddressForChain() internal view returns (address lendingPoolAddress_) {
        if (block.chainid == ETHEREUM_CHAIN_ID) {
            return ETHEREUM_AAVE_V2_LENDING_POOL_ADDRESS;
        } else if (block.chainid == POLYGON_CHAIN_ID) {
            return POLYGON_AAVE_V2_LENDING_POOL_ADDRESS;
        }
    }

    function increaseAaveV2TokenBalance(IERC20 _aToken, address _to, uint256 _amount) internal {
        IERC20 underlying = IERC20(IAaveAToken(address(_aToken)).UNDERLYING_ASSET_ADDRESS());

        // Increase underlying balance (allowing recursion as necessary, e.g., for stETH)
        increaseTokenBalance(underlying, _to, _amount);

        // Deposit underlying into Aave
        vm.startPrank(_to);
        // safeApprove() required for USDT
        address lendingPoolAddress = getAaveV2LendingPoolAddressForChain();
        underlying.safeApprove(lendingPoolAddress, _amount);
        IAaveV2LendingPool(lendingPoolAddress).deposit({
            _underlying: address(underlying),
            _amount: _amount,
            _to: _to,
            _referralCode: 0
        });
        vm.stopPrank();
    }

    function isAaveV2Token(IERC20 _token) internal view returns (bool isAToken_) {
        address lendingPoolAddress = getAaveV2LendingPoolAddressForChain();
        if (lendingPoolAddress == address(0)) {
            return false;
        }

        // Sniff out aTokens by interface
        (bool success, bytes memory returnData) =
            address(_token).staticcall(abi.encodeWithSelector(IAaveAToken.UNDERLYING_ASSET_ADDRESS.selector));

        if (!success) {
            return false;
        }

        // Check Aave to confirm the aToken is from this version.
        // Must do this to distinguish Aave v2 from v3 tokens.
        IERC20 underlying = IERC20(abi.decode(returnData, (address)));

        IAaveV2LendingPool.ReserveData memory reserveData =
            IAaveV2LendingPool(lendingPoolAddress).getReserveData(address(underlying));

        return address(_token) == reserveData.aTokenAddress;
    }

    // Aave v3

    function getAaveV3PoolAddressForChain() internal view returns (address lendingPoolAddress_) {
        if (block.chainid == ETHEREUM_CHAIN_ID) {
            return ETHEREUM_AAVE_V3_POOL_ADDRESS;
        } else if (block.chainid == POLYGON_CHAIN_ID) {
            return POLYGON_AAVE_V3_POOL_ADDRESS;
        }
    }

    function increaseAaveV3TokenBalance(IERC20 _aToken, address _to, uint256 _amount) internal {
        address lendingPoolAddress = getAaveV3PoolAddressForChain();

        IERC20 underlying = IERC20(IAaveAToken(address(_aToken)).UNDERLYING_ASSET_ADDRESS());

        // Increase underlying balance (allowing recursion as necessary, e.g., for stETH)
        increaseTokenBalance(underlying, _to, _amount);

        // Deposit underlying into Aave
        vm.startPrank(_to);
        // safeApprove() required for USDT
        underlying.safeApprove(lendingPoolAddress, _amount);
        IAaveV3Pool(lendingPoolAddress).supply({
            _asset: address(underlying),
            _amount: _amount,
            _onBehalfOf: _to,
            _referralCode: 0
        });
        vm.stopPrank();
    }

    function isAaveV3Token(IERC20 _token) internal view returns (bool isAToken_) {
        address poolAddress = getAaveV3PoolAddressForChain();
        if (poolAddress == address(0)) {
            return false;
        }

        // Sniff out aTokens by interface
        (bool success, bytes memory returnData) =
            address(_token).staticcall(abi.encodeWithSelector(IAaveAToken.UNDERLYING_ASSET_ADDRESS.selector));

        if (!success) {
            return false;
        }

        // Check Aave to confirm the aToken is from this version.
        // Must do this to distinguish Aave v2 from v3 tokens.
        IERC20 underlying = IERC20(abi.decode(returnData, (address)));

        IAaveV3Pool.ReserveData memory reserveData = IAaveV3Pool(poolAddress).getReserveData(address(underlying));

        return address(_token) == reserveData.aTokenAddress;
    }

    // Lido stETH

    function increaseStethBalance(address _to, uint256 _amount) internal {
        increaseNativeAssetBalance(_to, _amount);
        vm.prank(_to);
        ILidoSteth(ETHEREUM_STETH).submit{value: _amount}(_to);
    }

    function isSteth(IERC20 _token) internal view returns (bool isSteth_) {
        // Ethereum only
        if (block.chainid != ETHEREUM_CHAIN_ID) {
            return false;
        }

        return address(_token) == ETHEREUM_STETH;
    }
}
