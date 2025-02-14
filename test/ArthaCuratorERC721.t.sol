// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ArthaCuratorERC721} from "../src/ArthaCuratorERC721.sol";
import {Artha} from "../src/core/Artha.sol";
import {MockIrm} from "../src/core/mocks/MockIrm.sol";
import {MockUSDC} from "../src/core/mocks/MockUSDC.sol";
import {MockERC721} from "../src/core/mocks/MockERC721.sol";
import {PoolParams, Id} from "../src/core/interfaces/IArtha.sol";

contract ArthaCuratorTest is Test {
    ArthaCuratorERC721 public curator;
    Artha public artha;
    MockIrm public mockIrm;
    MockUSDC public mockUSDC;
    MockERC721 public collateralToken;

    Id public poolId1;
    Id public poolId2;
    Id public poolId3;

    MockERC721 public ip1;
    MockERC721 public ip2;
    MockERC721 public ip3;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    event DepositedToArtha(address indexed user, uint256 amount, uint256 mintedTokens);

    function setUp() public {
        vm.startPrank(owner);

        artha = new Artha();
        mockIrm = new MockIrm();
        mockUSDC = new MockUSDC();
        collateralToken = new MockERC721();
        artha.setInterestRateModel(address(mockIrm), true);
        artha.setLTV(90, true);
        artha.setLTV(80, true);

        PoolParams memory pool1Params = PoolParams({
            collateralToken: address(ip1),
            loanToken: address(mockUSDC),
            oracle: address(0),
            irm: address(mockIrm),
            ltv: 90,
            lth: 100
        });

        poolId1 = artha.createPool(pool1Params);

        curator = new ArthaCuratorERC721(address(artha), address(mockUSDC));
        artha.transferOwnership(address(curator));

        curator.setCurator(alice, true);
        vm.stopPrank();
    }

    function test_onlyOwnerCanSetCurator() public {
        vm.prank(bob);
        vm.expectRevert();
        curator.setCurator(bob, true);
    }

    function test_setAllocation() public {
        vm.startPrank(owner);

        bytes32[] memory pools = new bytes32[](2);
        pools[0] = Id.unwrap(poolId1);

        uint256[] memory allocations = new uint256[](2);
        allocations[0] = 0.6e6;

        curator.setAllocation(pools, allocations);

        assertEq(curator.poolList(0), Id.unwrap(poolId1), "Pool1 not correctly set");
        assertEq(curator.poolAlocations(Id.unwrap(poolId1)), allocations[0], "Pool1 allocation incorrect");

        vm.stopPrank();
    }

    function test_depositToArtha() public {
        vm.startPrank(owner);

        bytes32[] memory pools = new bytes32[](1);
        pools[0] = Id.unwrap(poolId1);

        uint256[] memory allocations = new uint256[](1);
        allocations[0] = 0.6e18;

        curator.setAllocation(pools, allocations);

        uint256 depositAmount = 1000 * 1e6;
        mockUSDC.mint(owner, depositAmount);
        mockUSDC.approve(address(curator), depositAmount);

        vm.expectEmit(true, true, true, true);
        emit DepositedToArtha(owner, depositAmount, depositAmount);

        curator.depositToArtha(depositAmount);

        assertEq(curator.totalAsset(), depositAmount * 60 / 100, "Total asset mismatch after deposit");
        assertEq(curator.balanceOf(owner), depositAmount, "Incorrect minted curator tokens for Owner");

        vm.stopPrank();
    }

    function test_withdrawFromArtha() public {
        vm.startPrank(owner);

        bytes32[] memory pools = new bytes32[](1);
        pools[0] = Id.unwrap(poolId1);

        uint256[] memory allocations = new uint256[](1);
        allocations[0] = 0.6e18;

        curator.setAllocation(pools, allocations);

        uint256 depositAmount = 1000 * 1e6;
        mockUSDC.mint(owner, depositAmount);
        mockUSDC.approve(address(curator), depositAmount);

        curator.depositToArtha(depositAmount);

        uint256 sharesToWithdraw = 500 * 1e6;
        curator.withdrawFromArtha(sharesToWithdraw);

        uint256 allocatedAmount = (depositAmount * allocations[0]) / 1e18;
        uint256 expectedWithdrawAmount = (sharesToWithdraw * allocatedAmount) / depositAmount;

        assertEq(mockUSDC.balanceOf(owner), expectedWithdrawAmount, "Incorrect amount withdrawn");

        assertEq(
            curator.balanceOf(owner),
            depositAmount - sharesToWithdraw,
            "Incorrect share balance for Owner after withdrawal"
        );

        vm.stopPrank();
    }
}
