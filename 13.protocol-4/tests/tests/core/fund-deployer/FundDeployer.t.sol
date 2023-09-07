// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IntegrationTest} from "tests/bases/IntegrationTest.sol";

import {IERC20} from "tests/interfaces/external/IERC20.sol";
import {IComptrollerLib} from "tests/interfaces/internal/IComptrollerLib.sol";
import {IFundDeployer} from "tests/interfaces/internal/IFundDeployer.sol";
import {IVaultLib} from "tests/interfaces/internal/IVaultLib.sol";
import {IVaultCore} from "tests/interfaces/internal/IVaultCore.sol";

// TODO: pseudo-constant setters (if no central router contract)
// TODO: setReleaseLive (relies on pseudo-constants)
// TODO: setGasLimitsForDestructCall (destruct calls might be removed all-together)

contract FundDeployerTest is IntegrationTest {
    // Comptroller events

    // ProtocolFeeCollector events
    event InitializedForVault(address vaultProxy);

    // FundDeployer events
    event ComptrollerProxyDeployed(
        address indexed creator,
        address comptrollerProxy,
        address indexed denominationAsset,
        uint256 sharesActionTimelock
    );

    event NewFundCreated(address indexed creator, address vaultProxy, address comptrollerProxy);

    function setUp() public override {
        setUpStandaloneEnvironment();
    }

    function test_getOwner_success() public {
        // Deploy a new FundDeployer
        IFundDeployer newFundDeployer = deployFundDeployer({
            _dispatcher: core.persistent.dispatcher,
            _gasRelayPaymasterFactory: core.release.gasRelayPaymasterFactory
        });

        // Owner starts as the FundDeployer contract deployer
        address creator = newFundDeployer.getOwner();

        // Set release live after setting the pseudo vars
        vm.startPrank(creator);
        newFundDeployer.setComptrollerLib(core.release.comptrollerLibAddress);
        newFundDeployer.setProtocolFeeTracker(address(core.release.protocolFeeTracker));
        newFundDeployer.setVaultLib(core.release.vaultLibAddress);
        newFundDeployer.setReleaseLive();
        vm.stopPrank();

        // Owner should be the Dispatcher owner
        assertEq(newFundDeployer.getOwner(), core.persistent.dispatcher.getOwner());
    }

    // TODO: use newFundDeployer instead of core.release.fundDeployer
    // function test_createNewFund_failWithNonLiveRelease() public {
    //     vm.expectRevert("Release is not yet live");

    //     core.release.fundDeployer.createNewFund({
    //         _fundOwner: makeAddr("FundOwner"),
    //         _fundName: "My Fund",
    //         _fundSymbol: "",
    //         _denominationAsset: makeAddr("DenominationAsset"),
    //         _sharesActionTimelock: 0,
    //         _feeManagerConfigData: "",
    //         _policyManagerConfigData: ""
    //     });
    // }

    function test_createNewFund_successWithNoExtraConfig() public {
        address fundCreator = makeAddr("FundCreator");
        address fundOwner = makeAddr("FundOwner");
        string memory fundName = "My Fund";
        uint256 sharesActionTimelock = 123;

        // Add denomination asset to the asset universe
        address denominationAsset = address(standardPrimitive);
        address expectedComptrollerProxy = predictComptrollerProxyAddress(core.release.fundDeployer);
        address expectedVaultProxyAddress = predictVaultProxyAddress(core.persistent.dispatcher);

        expectEmit(address(core.release.fundDeployer));
        emit ComptrollerProxyDeployed(fundCreator, expectedComptrollerProxy, denominationAsset, sharesActionTimelock);

        // TODO: Should this be tested in the protocol fee tracker tests?
        expectEmit(address(core.release.protocolFeeTracker));
        emit InitializedForVault(expectedVaultProxyAddress);

        expectEmit(address(core.release.fundDeployer));
        emit NewFundCreated(fundCreator, expectedVaultProxyAddress, expectedComptrollerProxy);

        vm.prank(fundCreator);
        (address comptrollerProxy, address vaultProxy) = core.release.fundDeployer.createNewFund({
            _fundOwner: fundOwner,
            _fundName: fundName,
            _fundSymbol: "",
            _denominationAsset: denominationAsset,
            _sharesActionTimelock: sharesActionTimelock,
            _feeManagerConfigData: "",
            _policyManagerConfigData: ""
        });

        // Assert the correct ComptrollerProxy state values
        assertEq(IComptrollerLib(comptrollerProxy).getDenominationAsset(), denominationAsset);
        assertEq(IComptrollerLib(comptrollerProxy).getSharesActionTimelock(), sharesActionTimelock);
        assertEq(IComptrollerLib(comptrollerProxy).getVaultProxy(), vaultProxy);

        // Assert the correct VaultProxy state values
        assertEq(IVaultLib(vaultProxy).getAccessor(), comptrollerProxy);
        assertEq(IVaultLib(vaultProxy).getOwner(), fundOwner);
        assertEq(IERC20(vaultProxy).name(), fundName);
        assertEq(IERC20(vaultProxy).symbol(), "ENZF");

        // TODO: calls the active() lifecycle function (?)
    }
}
