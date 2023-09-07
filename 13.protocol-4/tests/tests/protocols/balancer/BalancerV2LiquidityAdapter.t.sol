// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IntegrationTest} from "tests/bases/IntegrationTest.sol";
import {SpendAssetsHandleType} from "tests/utils/core/AdapterUtils.sol";
import {AddressArrayLib} from "tests/utils/libs/AddressArrayLib.sol";
import {Uint256ArrayLib} from "tests/utils/libs/Uint256ArrayLib.sol";

import {IBalancerV2Vault} from "tests/interfaces/external/IBalancerV2Vault.sol";
import {ICurveGaugeController} from "tests/interfaces/external/ICurveGaugeController.sol";
import {ICurveMinter} from "tests/interfaces/external/ICurveMinter.sol";
import {IERC20} from "tests/interfaces/external/IERC20.sol";

import {IBalancerV2LiquidityAdapter} from "tests/interfaces/internal/IBalancerV2LiquidityAdapter.sol";
import {IComptrollerLib} from "tests/interfaces/internal/IComptrollerLib.sol";
import {IIntegrationAdapter} from "tests/interfaces/internal/IIntegrationAdapter.sol";
import {IVaultLib} from "tests/interfaces/internal/IVaultLib.sol";

import {
    BalancerV2Utils,
    ComposableStablePoolExitKind,
    ComposableStablePoolJoinKind,
    LegacyStablePoolExitKind,
    LegacyStablePoolJoinKind,
    WeightedPoolExitKind,
    WeightedPoolJoinKind
} from "./BalancerV2Utils.sol";

abstract contract PoolTestBase is IntegrationTest, BalancerV2Utils {
    using AddressArrayLib for address[];
    using Uint256ArrayLib for uint256[];

    enum PoolType {
        None,
        Weighted,
        ComposableStable,
        LegacyStable
    }

    IBalancerV2Vault internal balancerVault = IBalancerV2Vault(VAULT_ADDRESS);

    address internal vaultOwner = makeAddr("VaultOwner");
    IVaultLib internal vaultProxy;
    IComptrollerLib internal comptrollerProxy;

    address[] internal poolAssetAddresses;

    // Vars defined by child contract
    IIntegrationAdapter internal adapter;
    bool internal isAura;
    IERC20 internal balToken;
    IERC20 internal poolBpt;
    bytes32 internal poolId;
    PoolType internal poolType;
    IERC20 internal stakingToken;

    function setUp() public virtual override {
        // Create fund with arbitrary denomination asset
        (comptrollerProxy, vaultProxy) = createVault({
            _fundDeployer: core.release.fundDeployer,
            _vaultOwner: vaultOwner,
            _denominationAsset: address(wethToken)
        });

        // Store pool assets
        (poolAssetAddresses,,) = balancerVault.getPoolTokens(poolId);

        // Add all pool assets, bpt, and stakingToken to asset universe to make them receivable
        // * must do after storing pool assets
        address[] memory tokensToRegister = toArray(address(poolBpt), address(stakingToken));
        tokensToRegister = tokensToRegister.mergeArray(poolAssetAddresses);
        addPrimitivesWithTestAggregator({
            _valueInterpreter: core.release.valueInterpreter,
            _tokenAddresses: tokensToRegister,
            _skipIfRegistered: true
        });
    }

    // ACTION HELPERS

    function __claimRewards() internal {
        bytes memory actionArgs = abi.encode(address(stakingToken));

        vm.prank(vaultOwner);
        callOnIntegration({
            _integrationManager: core.release.integrationManager,
            _comptrollerProxy: comptrollerProxy,
            _adapter: address(adapter),
            _selector: IBalancerV2LiquidityAdapter.claimRewards.selector,
            _actionArgs: actionArgs
        });
    }

    function __lendAndStake(
        address[] memory _spendAssets,
        uint256[] memory _spendAssetAmounts,
        uint256 _minIncomingBptAmount,
        IBalancerV2Vault.PoolBalanceChange memory _request
    ) internal {
        bytes memory actionArgs =
            abi.encode(address(stakingToken), poolId, _minIncomingBptAmount, _spendAssets, _spendAssetAmounts, _request);

        vm.prank(vaultOwner);
        callOnIntegration({
            _integrationManager: core.release.integrationManager,
            _comptrollerProxy: comptrollerProxy,
            _adapter: address(adapter),
            _selector: IBalancerV2LiquidityAdapter.lendAndStake.selector,
            _actionArgs: actionArgs
        });
    }

    function __stake(uint256 _amount) internal {
        bytes memory actionArgs = abi.encode(address(stakingToken), _amount);

        vm.prank(vaultOwner);
        callOnIntegration({
            _integrationManager: core.release.integrationManager,
            _comptrollerProxy: comptrollerProxy,
            _adapter: address(adapter),
            _selector: IBalancerV2LiquidityAdapter.stake.selector,
            _actionArgs: actionArgs
        });
    }

    function __unstake(uint256 _amount) internal {
        bytes memory actionArgs = abi.encode(address(stakingToken), _amount);

        vm.prank(vaultOwner);
        callOnIntegration({
            _integrationManager: core.release.integrationManager,
            _comptrollerProxy: comptrollerProxy,
            _adapter: address(adapter),
            _selector: IBalancerV2LiquidityAdapter.unstake.selector,
            _actionArgs: actionArgs
        });
    }

    function __unstakeAndRedeem(
        uint256 _bptAmount,
        address[] memory _incomingAssetAddresses,
        uint256[] memory _minIncomingAssetAmounts,
        IBalancerV2Vault.PoolBalanceChange memory _request
    ) internal {
        bytes memory actionArgs = abi.encode(
            address(stakingToken), poolId, _bptAmount, _incomingAssetAddresses, _minIncomingAssetAmounts, _request
        );

        vm.prank(vaultOwner);
        callOnIntegration({
            _integrationManager: core.release.integrationManager,
            _comptrollerProxy: comptrollerProxy,
            _adapter: address(adapter),
            _selector: IBalancerV2LiquidityAdapter.unstakeAndRedeem.selector,
            _actionArgs: actionArgs
        });
    }

    // MISC HELPERS

    function __constructRequest(uint256[] memory _limits, bytes memory _userData)
        internal
        view
        returns (IBalancerV2Vault.PoolBalanceChange memory request_)
    {
        return IBalancerV2Vault.PoolBalanceChange({
            assets: poolAssetAddresses,
            limits: _limits,
            userData: _userData,
            useInternalBalance: false
        });
    }

    function __constructRequestBptInForExactTokensOut(uint256[] memory _verboseAmountsOut, uint256 _maxBptAmountIn)
        internal
        view
        returns (IBalancerV2Vault.PoolBalanceChange memory request_)
    {
        uint256[] memory amountsOutWithoutBpt = _verboseAmountsOut;
        (bool bptFound, uint256 bptIndex) = poolAssetAddresses.find(address(poolBpt));
        if (bptFound) {
            amountsOutWithoutBpt = amountsOutWithoutBpt.removeAtIndex(bptIndex);
        }

        // `userData` uses truncated tokens excluding bpt
        bytes memory userData = abi.encode(__getExitKindBptInForExactTokensOut(), amountsOutWithoutBpt, _maxBptAmountIn);

        return __constructRequest({_limits: _verboseAmountsOut, _userData: userData});
    }

    function __constructRequestTokenInForExactBptOut(uint256 _bptAmountOut, IERC20 _tokenIn, uint256 _maxTokenInAmount)
        internal
        view
        returns (IBalancerV2Vault.PoolBalanceChange memory request_)
    {
        (bool tokenInFound, uint256 tokenInIndex) = poolAssetAddresses.find(address(_tokenIn));
        require(tokenInFound, "__constructRequestTokenInForExactBptOut: Token not found");

        uint256 tokenInIndexWithoutBpt = tokenInIndex;
        (bool bptFound, uint256 bptIndex) = poolAssetAddresses.find(address(poolBpt));
        if (bptFound && bptIndex < tokenInIndex) {
            tokenInIndexWithoutBpt--;
        }

        // `userData` uses truncated tokens excluding bpt
        bytes memory userData = abi.encode(__getJoinKindTokenInForExactBptOut(), _bptAmountOut, tokenInIndexWithoutBpt);

        // `limits` uses verbose tokens including bpt
        uint256[] memory limits = new uint256[](poolAssetAddresses.length);
        limits[tokenInIndex] = _maxTokenInAmount;

        return __constructRequest({_limits: limits, _userData: userData});
    }

    function __findLastNonBptAsset() internal view returns (IERC20 asset_) {
        uint256 assetIndex = poolAssetAddresses.length - 1;
        if (poolAssetAddresses[assetIndex] == address(poolBpt)) {
            assetIndex--;
        }

        return IERC20(poolAssetAddresses[assetIndex]);
    }

    function __getExitKindBptInForExactTokensOut() internal view returns (uint8 joinKind_) {
        if (poolType == PoolType.Weighted) {
            return uint8(WeightedPoolExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT);
        } else if (poolType == PoolType.ComposableStable) {
            return uint8(ComposableStablePoolExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT);
        } else if (poolType == PoolType.LegacyStable) {
            return uint8(LegacyStablePoolExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT);
        }

        revert("No pool type");
    }

    function __getExitKindExactBptInForOneTokenOut() internal view returns (uint8 joinKind_) {
        if (poolType == PoolType.Weighted) {
            return uint8(WeightedPoolExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT);
        } else if (poolType == PoolType.ComposableStable) {
            return uint8(ComposableStablePoolExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT);
        } else if (poolType == PoolType.LegacyStable) {
            return uint8(LegacyStablePoolExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT);
        }

        revert("No pool type");
    }

    function __getExitKindExactBptInForTokensOut() internal view returns (uint8 joinKind_) {
        if (poolType == PoolType.Weighted) {
            return uint8(WeightedPoolExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT);
        } else if (poolType == PoolType.ComposableStable) {
            return uint8(ComposableStablePoolExitKind.EXACT_BPT_IN_FOR_ALL_TOKENS_OUT);
        } else if (poolType == PoolType.LegacyStable) {
            return uint8(LegacyStablePoolExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT);
        }

        revert("No pool type");
    }

    function __getJoinKindExactTokensInForBptOut() internal view returns (uint8 joinKind_) {
        if (poolType == PoolType.Weighted) {
            return uint8(WeightedPoolJoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT);
        } else if (poolType == PoolType.ComposableStable) {
            return uint8(ComposableStablePoolJoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT);
        } else if (poolType == PoolType.LegacyStable) {
            return uint8(LegacyStablePoolJoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT);
        }

        revert("No pool type");
    }

    function __getJoinKindTokenInForExactBptOut() internal view returns (uint8 joinKind_) {
        if (poolType == PoolType.Weighted) {
            return uint8(WeightedPoolJoinKind.TOKEN_IN_FOR_EXACT_BPT_OUT);
        } else if (poolType == PoolType.ComposableStable) {
            return uint8(ComposableStablePoolJoinKind.TOKEN_IN_FOR_EXACT_BPT_OUT);
        } else if (poolType == PoolType.LegacyStable) {
            return uint8(LegacyStablePoolJoinKind.TOKEN_IN_FOR_EXACT_BPT_OUT);
        }

        revert("No pool type");
    }

    // Quickly identify if a test is Balancer on mainnet, or Aura/sidechain
    function __isBalancerMainnetTest() internal view returns (bool isBalancerMainnet_) {
        return !isAura && address(balToken) == ETHEREUM_BAL;
    }
}

abstract contract BalancerAndAuraPoolTest is PoolTestBase {
    using AddressArrayLib for address[];
    using Uint256ArrayLib for uint256[];

    function test_claimRewards_success() public {
        // Setup rewards claiming on the Minter (mainnet Balancer tests only)
        if (__isBalancerMainnetTest()) {
            // Approve adapter to call Minter on behalf of the vault
            registerVaultCall({
                _fundDeployer: core.release.fundDeployer,
                _contract: ETHEREUM_MINTER_ADDRESS,
                _selector: ICurveMinter.toggle_approve_mint.selector
            });
            vm.prank(vaultOwner);
            comptrollerProxy.vaultCallOnContract({
                _contract: ETHEREUM_MINTER_ADDRESS,
                _selector: ICurveMinter.toggle_approve_mint.selector,
                _encodedArgs: abi.encode(address(adapter))
            });

            // Make sure the gauge has some weight so it earns BAL rewards via the Minter
            uint256 totalWeight = ICurveGaugeController(ETHEREUM_GAUGE_CONTROLLER_ADDRESS).get_total_weight();
            vm.prank(ETHEREUM_AUTHORIZER_ADAPTER_ADDRESS);
            ICurveGaugeController(ETHEREUM_GAUGE_CONTROLLER_ADDRESS).change_gauge_weight({
                _gauge: address(stakingToken),
                _weight: totalWeight / 10
            });
        }

        // Seed the vault with bpt and stake them to start accruing rewards
        uint256 stakingTokenBalance = assetUnit(stakingToken) * 1000;
        deal({token: address(poolBpt), to: address(vaultProxy), give: stakingTokenBalance});
        __stake(stakingTokenBalance);

        // Warp ahead in time to accrue significant rewards
        vm.warp(block.timestamp + SECONDS_ONE_YEAR);

        // Seed the staking token with some BAL for rewards (Balancer sidechains and Aura)
        // Incidentally, this also tests the extra rewards are claimed correctly, since BAL is treated as an extra reward on side-chains
        if (!__isBalancerMainnetTest()) {
            increaseTokenBalance({_token: balToken, _to: address(stakingToken), _amount: assetUnit(balToken) * 10_000});
        }

        vm.recordLogs();

        // Claim rewards
        __claimRewards();

        // Test parseAssetsForAction encoding.
        // All should be empty.
        assertAdapterAssetsForAction({
            _logs: vm.getRecordedLogs(),
            _spendAssetsHandleType: SpendAssetsHandleType.None,
            _spendAssets: new address[](0),
            _maxSpendAssetAmounts: new uint256[](0),
            _incomingAssets: new address[](0),
            _minIncomingAssetAmounts: new uint256[](0)
        });

        // Assert vault balances of reward tokens have increased
        // TODO: set extra reward token
        assertTrue(balToken.balanceOf(address(vaultProxy)) > 0, "no bal token received");
    }

    function test_lendAndStake_successWithExactBptOut() public {
        IERC20 spendAsset = __findLastNonBptAsset();

        // Arbitrary amounts, incomingBptAmount must be valued less than maxSpendAssetAmount
        uint256 maxSpendAssetAmount = assetUnit(spendAsset) * 1000;
        uint256 incomingBptAmount = assetUnit(poolBpt) * 3;
        uint256 minIncomingBptAmount = 123;

        // Seed the vault with max spend asset amount
        deal({token: address(spendAsset), to: address(vaultProxy), give: maxSpendAssetAmount});

        IBalancerV2Vault.PoolBalanceChange memory request = __constructRequestTokenInForExactBptOut({
            _bptAmountOut: incomingBptAmount,
            _tokenIn: spendAsset,
            _maxTokenInAmount: maxSpendAssetAmount
        });

        vm.recordLogs();

        __lendAndStake({
            _spendAssets: toArray(address(spendAsset)),
            _spendAssetAmounts: toArray(maxSpendAssetAmount),
            _minIncomingBptAmount: minIncomingBptAmount,
            _request: request
        });

        // Test parseAssetsForAction encoding
        assertAdapterAssetsForAction({
            _logs: vm.getRecordedLogs(),
            _spendAssetsHandleType: SpendAssetsHandleType.Transfer,
            _spendAssets: toArray(address(spendAsset)),
            _maxSpendAssetAmounts: toArray(maxSpendAssetAmount),
            _incomingAssets: toArray(address(stakingToken)),
            _minIncomingAssetAmounts: toArray(minIncomingBptAmount)
        });

        // Received staking token amount should be exactly as-specified
        assertEq(
            stakingToken.balanceOf(address(vaultProxy)), incomingBptAmount, "incorrect final staking token balance"
        );
        // There should be some unused amount of the spend asset that has been returned to the vault
        assertTrue(spendAsset.balanceOf(address(vaultProxy)) > 0, "incorrect final spend asset balance");
    }

    function test_stake_success() public {
        // Seed the vault with unstaked bpt
        uint256 preTxBptBalance = assetUnit(stakingToken) * 1000;
        deal({token: address(poolBpt), to: address(vaultProxy), give: preTxBptBalance});

        uint256 bptToStake = preTxBptBalance / 5;

        vm.recordLogs();

        __stake(bptToStake);

        // Test parseAssetsForAction encoding
        assertAdapterAssetsForAction({
            _logs: vm.getRecordedLogs(),
            _spendAssetsHandleType: SpendAssetsHandleType.Transfer,
            _spendAssets: toArray(address(poolBpt)),
            _maxSpendAssetAmounts: toArray(bptToStake),
            _incomingAssets: toArray(address(stakingToken)),
            _minIncomingAssetAmounts: toArray(bptToStake)
        });

        assertEq(stakingToken.balanceOf(address(vaultProxy)), bptToStake, "incorrect final staking token balance");
        assertEq(poolBpt.balanceOf(address(vaultProxy)), preTxBptBalance - bptToStake, "incorrect final bpt balance");
    }

    function test_unstake_success() public {
        // Seed the vault with bpt and stake them
        uint256 preTxStakingTokenBalance = assetUnit(stakingToken) * 1000;
        deal({token: address(poolBpt), to: address(vaultProxy), give: preTxStakingTokenBalance});
        __stake(preTxStakingTokenBalance);

        uint256 bptToUnstake = preTxStakingTokenBalance / 5;

        vm.recordLogs();

        __unstake(bptToUnstake);

        // Test parseAssetsForAction encoding
        assertAdapterAssetsForAction({
            _logs: vm.getRecordedLogs(),
            _spendAssetsHandleType: isAura ? SpendAssetsHandleType.Approve : SpendAssetsHandleType.Transfer,
            _spendAssets: toArray(address(stakingToken)),
            _maxSpendAssetAmounts: toArray(bptToUnstake),
            _incomingAssets: toArray(address(poolBpt)),
            _minIncomingAssetAmounts: toArray(bptToUnstake)
        });

        assertEq(
            stakingToken.balanceOf(address(vaultProxy)),
            preTxStakingTokenBalance - bptToUnstake,
            "incorrect final staking token balance"
        );
        assertEq(poolBpt.balanceOf(address(vaultProxy)), bptToUnstake, "incorrect final bpt balance");
    }

    function test_unstakeAndRedeem_successWithExactTokensOut() public {
        // Seed the vault with bpt and stake them
        uint256 preTxStakingTokenBalance = assetUnit(stakingToken) * 1000;
        deal({token: address(poolBpt), to: address(vaultProxy), give: preTxStakingTokenBalance});
        __stake(preTxStakingTokenBalance);

        uint256 unstakeAmount = preTxStakingTokenBalance / 3;

        // Define decreasing arbitrary incoming amounts for all non-bpt pool assets
        uint256 assetUnitDivisor = 1;
        uint256[] memory verboseIncomingAssetAmounts = new uint256[](poolAssetAddresses.length);
        for (uint256 i; i < poolAssetAddresses.length; i++) {
            address poolAssetAddress = poolAssetAddresses[i];
            if (poolAssetAddress != address(poolBpt)) {
                verboseIncomingAssetAmounts[i] = assetUnit(IERC20(poolAssetAddress)) / assetUnitDivisor;
                assetUnitDivisor += 2;
            }
        }

        // Truncate asset and amount arrays without bpt
        address[] memory incomingAssetAddressesWithoutBpt = poolAssetAddresses;
        uint256[] memory incomingAssetAmountsWithoutBpt = verboseIncomingAssetAmounts;
        (bool bptFound, uint256 bptIndex) = poolAssetAddresses.find(address(poolBpt));
        if (bptFound) {
            incomingAssetAddressesWithoutBpt = incomingAssetAddressesWithoutBpt.removeAtIndex(bptIndex);
            incomingAssetAmountsWithoutBpt = incomingAssetAmountsWithoutBpt.removeAtIndex(bptIndex);
        }

        IBalancerV2Vault.PoolBalanceChange memory request = __constructRequestBptInForExactTokensOut({
            _verboseAmountsOut: verboseIncomingAssetAmounts,
            _maxBptAmountIn: preTxStakingTokenBalance
        });

        vm.recordLogs();

        __unstakeAndRedeem({
            _bptAmount: unstakeAmount,
            _incomingAssetAddresses: incomingAssetAddressesWithoutBpt,
            _minIncomingAssetAmounts: incomingAssetAmountsWithoutBpt,
            _request: request
        });

        // Test parseAssetsForAction encoding
        assertAdapterAssetsForAction({
            _logs: vm.getRecordedLogs(),
            _spendAssetsHandleType: isAura ? SpendAssetsHandleType.Approve : SpendAssetsHandleType.Transfer,
            _spendAssets: toArray(address(stakingToken)),
            _maxSpendAssetAmounts: toArray(unstakeAmount),
            _incomingAssets: incomingAssetAddressesWithoutBpt,
            _minIncomingAssetAmounts: incomingAssetAmountsWithoutBpt
        });

        // Exact amounts of each incoming asset should have been received
        for (uint256 i; i < incomingAssetAddressesWithoutBpt.length; i++) {
            IERC20 incomingAsset = IERC20(incomingAssetAddressesWithoutBpt[i]);
            assertEq(
                incomingAsset.balanceOf(address(vaultProxy)),
                incomingAssetAmountsWithoutBpt[i],
                "incorrect final incoming asset balance"
            );
        }

        // Any unused bpt should been re-staked.
        // and the adapter should have no bpt balance.
        uint256 postTxStakingTokenBalance = stakingToken.balanceOf(address(vaultProxy));
        assertTrue(postTxStakingTokenBalance > preTxStakingTokenBalance - unstakeAmount, "no re-staked bpt");
        assertEq(poolBpt.balanceOf(address(adapter)), 0, "adapter still has bpt");
    }

    // TODO: takeOrder() tests
}

abstract contract BalancerPoolTest is BalancerAndAuraPoolTest {
    function __deployAdapter(address _minterAddress) internal returns (address adapterAddress_) {
        bytes memory args = abi.encode(core.release.integrationManager, balancerVault, _minterAddress, balToken);

        return deployCode("BalancerV2LiquidityAdapter.sol", args);
    }

    // TODO: add Balancer-only tests here
}

abstract contract EthereumBalancerPoolTest is BalancerPoolTest {
    function setUp() public virtual override {
        setUpMainnetEnvironment();

        balToken = IERC20(ETHEREUM_BAL);

        // Deploy the adapter
        adapter = IIntegrationAdapter(__deployAdapter(ETHEREUM_MINTER_ADDRESS));

        // Run common setup
        super.setUp();
    }
}

abstract contract PolygonBalancerPoolTest is BalancerPoolTest {
    function setUp() public virtual override {
        setUpPolygonEnvironment();

        balToken = IERC20(POLYGON_BAL);

        // Deploy the adapter
        adapter = IIntegrationAdapter(__deployAdapter(address(0)));

        super.setUp();
    }
}

// ACTUAL TESTS, RUN PER-POOL

contract EthereumUsdcDaiUsdtPoolTest is EthereumBalancerPoolTest {
    function setUp() public override {
        // Define pool before all other setup
        poolId = ETHEREUM_USDC_DAI_USDT_POOL_ID;
        poolBpt = IERC20(ETHEREUM_USDC_DAI_USDT_POOL_ADDRESS);
        poolType = PoolType.ComposableStable;
        stakingToken = IERC20(ETHEREUM_USDC_DAI_USDT_POOL_GAUGE_ADDRESS);

        super.setUp();
    }
}

contract PolygonTriCryptoPoolTest is PolygonBalancerPoolTest {
    function setUp() public override {
        // Define pool before all other setup
        poolId = POLYGON_TRICRYPTO_POOL_ID;
        poolBpt = IERC20(POLYGON_TRICRYPTO_POOL_ADDRESS);
        poolType = PoolType.Weighted;
        stakingToken = IERC20(POLYGON_TRICRYPTO_POOL_GAUGE_ADDRESS);

        super.setUp();
    }
}
