// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IntegrationTest} from "tests/bases/IntegrationTest.sol";
import {IAaveAToken} from "tests/interfaces/external/IAaveAToken.sol";
import {IERC20} from "tests/interfaces/external/IERC20.sol";
import {IAaveV2Adapter} from "tests/interfaces/internal/IAaveV2Adapter.sol";
import {IComptrollerLib} from "tests/interfaces/internal/IComptrollerLib.sol";
import {IVaultLib} from "tests/interfaces/internal/IVaultLib.sol";
import {SpendAssetsHandleType} from "tests/utils/core/AdapterUtils.sol";

abstract contract AaveAdapterTestBase is IntegrationTest {
    uint256 internal constant ROUNDING_BUFFER = 2;

    address internal vaultOwner = makeAddr("VaultOwner");
    address internal sharesBuyer = makeAddr("SharesBuyer");

    IVaultLib internal vaultProxy;
    IComptrollerLib internal comptrollerProxy;

    address internal adapter;
    address internal lendingPool;
    address internal lendingPoolAddressProvider;

    IERC20 internal regular18DecimalUnderlying;
    IERC20 internal non18DecimalUnderlying;

    function setUp() public virtual override {
        (comptrollerProxy, vaultProxy) = createVaultAndBuyShares({
            _fundDeployer: core.release.fundDeployer,
            _vaultOwner: vaultOwner,
            _sharesBuyer: sharesBuyer,
            _denominationAsset: address(wethToken),
            _amountToDeposit: 1000 ether
        });
    }

    // ACTION HELPERS

    function __lend(address _aToken, uint256 _amount) internal {
        bytes memory actionArgs = abi.encode(_aToken, _amount);

        vm.prank(vaultOwner);
        callOnIntegration({
            _integrationManager: core.release.integrationManager,
            _comptrollerProxy: comptrollerProxy,
            _adapter: address(adapter),
            _selector: IAaveV2Adapter.lend.selector, // selectors are the same for V2 and V3
            _actionArgs: actionArgs
        });
    }

    function __redeem(address _aToken, uint256 _amount) internal {
        bytes memory actionArgs = abi.encode(_aToken, _amount);

        vm.prank(vaultOwner);
        callOnIntegration({
            _integrationManager: core.release.integrationManager,
            _comptrollerProxy: comptrollerProxy,
            _adapter: address(adapter),
            _selector: IAaveV2Adapter.redeem.selector, // selectors are the same for V2 and V3
            _actionArgs: actionArgs
        });
    }

    // MISC HELPERS
    function __getATokenAddress(address _underlying) internal view virtual returns (address);
}

abstract contract AaveAdapterLendTest is AaveAdapterTestBase {
    function test_lend_success() public {
        __test_lend_success({
            _aToken: __getATokenAddress(address(regular18DecimalUnderlying)),
            _amount: 6 * assetUnit(regular18DecimalUnderlying)
        });

        // test underlying with decimals that are not 18
        __test_lend_success({
            _aToken: __getATokenAddress(address(non18DecimalUnderlying)),
            _amount: 10 * assetUnit(non18DecimalUnderlying)
        });
    }

    function __test_lend_success(address _aToken, uint256 _amount) internal {
        address underlying = IAaveAToken(_aToken).UNDERLYING_ASSET_ADDRESS();

        increaseTokenBalance({_token: IERC20(underlying), _to: address(vaultProxy), _amount: _amount});

        vm.recordLogs();

        __lend({_aToken: _aToken, _amount: _amount});

        // Test parseAssetsForAction encoding.
        assertAdapterAssetsForAction({
            _logs: vm.getRecordedLogs(),
            _spendAssetsHandleType: SpendAssetsHandleType.Transfer,
            _spendAssets: toArray(underlying),
            _maxSpendAssetAmounts: toArray(_amount),
            _incomingAssets: toArray(_aToken),
            _minIncomingAssetAmounts: toArray(_amount - ROUNDING_BUFFER)
        });

        assertApproxEqAbs(
            IERC20(_aToken).balanceOf(address(vaultProxy)),
            _amount,
            ROUNDING_BUFFER,
            "AToken balance of vault after lend is incorrect"
        );
    }

    function test_lend_failInvalidAToken() public {
        // create fake aToken and underlying
        address fakeAToken = address(createTestToken("Fake AToken"));
        address fakeUnderlying = address(createTestToken("Fake Underlying"));
        // mock aToken's underlying asset
        vm.mockCall({
            callee: fakeAToken,
            data: abi.encodeWithSelector(IAaveAToken.UNDERLYING_ASSET_ADDRESS.selector),
            returnData: abi.encode(fakeUnderlying)
        });

        // register incoming asset
        addPrimitiveWithTestAggregator({
            _valueInterpreter: core.release.valueInterpreter,
            _tokenAddress: fakeAToken,
            _skipIfRegistered: false
        });

        // lend minimal amount
        uint256 amountToLend = 1 + ROUNDING_BUFFER;

        // increase vault's fake aToken balance, so it won't revert, because of insufficient balance
        increaseTokenBalance({_token: IERC20(fakeUnderlying), _to: address(vaultProxy), _amount: amountToLend});

        vm.expectRevert(formatError("__validateItems: Invalid aToken"));

        // try to lend
        __lend({_aToken: fakeAToken, _amount: amountToLend});
    }
}

abstract contract AaveAdapterRedeemTest is AaveAdapterTestBase {
    function test_redeem_success() public {
        __test_redeem_success({
            _aToken: __getATokenAddress(address(regular18DecimalUnderlying)),
            _amount: 6 * assetUnit(regular18DecimalUnderlying)
        });

        // test underlying with decimals that are not 18
        __test_redeem_success({
            _aToken: __getATokenAddress(address(non18DecimalUnderlying)),
            _amount: 10 * assetUnit(non18DecimalUnderlying)
        });
    }

    function __test_redeem_success(address _aToken, uint256 _amount) internal {
        address underlying = IAaveAToken(_aToken).UNDERLYING_ASSET_ADDRESS();

        increaseTokenBalance({_token: IERC20(_aToken), _to: address(vaultProxy), _amount: _amount});

        // balance of vault before redeem
        uint256 vaultBalanceBefore = IERC20(underlying).balanceOf(address(vaultProxy));

        vm.recordLogs();

        __redeem({_aToken: _aToken, _amount: _amount});

        // Test parseAssetsForAction encoding.
        assertAdapterAssetsForAction({
            _logs: vm.getRecordedLogs(),
            _spendAssetsHandleType: SpendAssetsHandleType.Transfer,
            _spendAssets: toArray(_aToken),
            _maxSpendAssetAmounts: toArray(_amount),
            _incomingAssets: toArray(underlying),
            _minIncomingAssetAmounts: toArray(_amount - ROUNDING_BUFFER)
        });

        // balance of vault after redeem
        uint256 vaultBalanceAfter = IERC20(underlying).balanceOf(address(vaultProxy));

        // balance of vault should be increased by _amount
        assertApproxEqAbs(
            vaultBalanceBefore + _amount,
            vaultBalanceAfter,
            ROUNDING_BUFFER,
            "Underlying vault balance after redeem is incorrect"
        );
    }

    function test_redeem_failInvalidAToken() public {
        // create fake aToken and underlying
        address fakeAToken = address(createTestToken("Fake AToken"));
        address fakeUnderlying = address(createTestToken("Fake Underlying"));
        // mock aToken's underlying asset
        vm.mockCall({
            callee: fakeAToken,
            data: abi.encodeWithSelector(IAaveAToken.UNDERLYING_ASSET_ADDRESS.selector),
            returnData: abi.encode(fakeUnderlying)
        });

        // register incoming asset
        addPrimitiveWithTestAggregator({
            _valueInterpreter: core.release.valueInterpreter,
            _tokenAddress: fakeUnderlying,
            _skipIfRegistered: false
        });

        // redeem minimal amount
        uint256 amountToRedeem = 1 + ROUNDING_BUFFER;

        // increase vault's fake aToken balance, so it won't revert, because of insufficient balance
        increaseTokenBalance({_token: IERC20(fakeAToken), _to: address(vaultProxy), _amount: amountToRedeem});

        vm.expectRevert(formatError("__validateItems: Invalid aToken"));

        // try to redeem
        __redeem({_aToken: fakeAToken, _amount: amountToRedeem});
    }
}

abstract contract AaveAdapterTest is AaveAdapterLendTest, AaveAdapterRedeemTest {}
