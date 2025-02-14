// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ArthaCurator} from "../src/ArthaCurator.sol";
import {Artha} from "../src/core/Artha.sol";
import {MockIrm} from "../src/core/mocks/MockIrm.sol";
import {MockUSDC} from "../src/core/mocks/MockUSDC.sol";
import {PoolParams, Id} from "../src/core/interfaces/IArtha.sol";

contract ArthaCuratorTest is Test {
    ArthaCurator public curator;
    Artha public artha;
    MockIrm public mockIrm;
    MockUSDC public mockUSDC;

    Id public poolId1;
    Id public poolId2;
    Id public poolId3;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public feeRecipient = makeAddr("feeRecipient");

    function setUp() public {
        vm.startPrank(owner);

        artha = new Artha();
        mockIrm = new MockIrm();
        mockUSDC = new MockUSDC();

        artha.setInterestRateModel(address(mockIrm), true);

        artha.setLTV(90, true);
        PoolParams memory pool1Params = PoolParams({
            collateralToken: address(0),
            loanToken: address(mockUSDC),
            oracle: address(0),
            irm: address(mockIrm),
            ltv: 90,
            lth: 100
        });
        poolId1 = artha.createPool(pool1Params);

        artha.setLTV(85, true);
        PoolParams memory pool2Params = PoolParams({
            collateralToken: address(0),
            loanToken: address(mockUSDC),
            oracle: address(0),
            irm: address(mockIrm),
            ltv: 85,
            lth: 95
        });
        poolId2 = artha.createPool(pool2Params);

        artha.setLTV(80, true);
        PoolParams memory pool3Params = PoolParams({
            collateralToken: address(0),
            loanToken: address(mockUSDC),
            oracle: address(0),
            irm: address(mockIrm),
            ltv: 80,
            lth: 90
        });
        poolId3 = artha.createPool(pool3Params);

        curator = new ArthaCurator(address(artha), address(mockUSDC));
        artha.transferOwnership(address(curator));

        vm.stopPrank();
    }

    function test_setFeeRecipient() public {
        vm.startPrank(owner);

        curator.setFeeRecipient(feeRecipient);
        assertEq(curator.feeRecipient(), feeRecipient, "Fee recipient not set correctly");

        vm.stopPrank();
    }

    function test_setFeePercentage() public {
        vm.startPrank(owner);

        uint256 feePercentage = 100; // 1%
        curator.setFeePercentage(feePercentage);
        assertEq(curator.feePercentage(), feePercentage, "Fee percentage not set correctly");

        vm.stopPrank();
    }

    function test_deposit() public {
        vm.startPrank(owner);

        curator.setFeeRecipient(feeRecipient);
        uint256 feePercentage = 100; // 1%
        curator.setFeePercentage(feePercentage);

        bytes32[] memory pools = new bytes32[](3);
        pools[0] = Id.unwrap(poolId1);
        pools[1] = Id.unwrap(poolId2);
        pools[2] = Id.unwrap(poolId3);

        uint256[] memory allocations = new uint256[](3);
        allocations[0] = 0.4e18;
        allocations[1] = 0.35e18;
        allocations[2] = 0.25e18;

        curator.setAllocation(pools, allocations);

        uint256 depositAmount = 1000 * 1e6;
        mockUSDC.mint(owner, depositAmount);
        mockUSDC.approve(address(curator), depositAmount);

        uint256 previewedShares = curator.previewDeposit(depositAmount);
        uint256 sharesMinted = curator.deposit(depositAmount, owner);

        uint256 expectedFeeShares = (previewedShares * feePercentage) / 10000;
        uint256 expectedUserShares = previewedShares - expectedFeeShares;

        assertEq(sharesMinted, expectedUserShares, "Incorrect shares minted for Owner after fee");
        assertEq(curator.balanceOf(feeRecipient), expectedFeeShares, "Incorrect fee shares minted");
        assertEq(previewedShares, sharesMinted + expectedFeeShares, "PreviewDeposit does not match actual deposit");

        vm.stopPrank();
    }

    function test_redeem() public {
        vm.startPrank(owner);

        curator.setFeeRecipient(feeRecipient);
        uint256 feePercentage = 100;
        curator.setFeePercentage(feePercentage);

        bytes32[] memory pools = new bytes32[](3);
        pools[0] = Id.unwrap(poolId1);
        pools[1] = Id.unwrap(poolId2);
        pools[2] = Id.unwrap(poolId3);

        uint256[] memory allocations = new uint256[](3);
        allocations[0] = 0.4e18;
        allocations[1] = 0.35e18;
        allocations[2] = 0.25e18;

        curator.setAllocation(pools, allocations);

        uint256 depositAmount = 1000 * 1e6;
        mockUSDC.mint(owner, depositAmount);
        mockUSDC.approve(address(curator), depositAmount);

        uint256 sharesMinted = curator.deposit(depositAmount, owner);

        uint256 sharesToRedeem = 500 * 1e6;
        uint256 previewedAssets = curator.previewRedeem(sharesToRedeem);
        uint256 redeemedAssets = curator.redeem(sharesToRedeem, owner, owner);

        assertEq(previewedAssets, redeemedAssets, "PreviewRedeem does not match actual redeem");

        vm.stopPrank();
    }
}
