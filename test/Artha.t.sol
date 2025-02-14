// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IArtha, Id, Pool, Position, PoolParams} from "../src/core/interfaces/IArtha.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Iirm} from "../src/core/interfaces/IIrm.sol";
import {MockIrm} from "../src/core/mocks/MockIrm.sol";
import {MockUSDC} from "../src/core/mocks/MockUSDC.sol";
import {MockERC721} from "../src/core/mocks/MockERC721.sol";
import {Artha} from "../src/core/Artha.sol";

contract ArthaTest is Test {
    Artha public artha;
    MockIrm public mockIrm;
    MockUSDC public mockUSDC;

    // pools
    Id public poolId1;
    Id public poolId2;
    Id public poolId3;

    // IPs
    MockERC721 public ip1;
    MockERC721 public ip2;
    MockERC721 public ip3;

    // users
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    function setUp() public {
        mockUSDC = new MockUSDC();
        mockIrm = new MockIrm();
        artha = new Artha();

        ip1 = new MockERC721();
        ip2 = new MockERC721();
        ip3 = new MockERC721();

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

        // mints
        ip1.mint(alice, 1);
        mockUSDC.mint(alice, 1000e6);
    }

    function test_createPool() public {
        (,,,,,,,,,, uint256 lastAccrued) = artha.pools(poolId1);
        assertNotEq(lastAccrued, 0);

        // create pool 2
        PoolParams memory pool2Params = PoolParams({
            collateralToken: address(ip2),
            loanToken: address(mockUSDC),
            oracle: address(0),
            irm: address(mockIrm),
            ltv: 80,
            lth: 90
        });

        poolId2 = artha.createPool(pool2Params);

        assertNotEq(Id.unwrap(poolId2), bytes32(0));
    }

    function test_supply() public {
        vm.startPrank(alice);
        mockUSDC.approve(address(artha), 1000e6);
        artha.supply(poolId1, 1000e6, alice);

        assertEq(artha.supplies(poolId1, alice), 1000e6);
    }

    function test_withdraw() public {
        vm.startPrank(bob);
        mockUSDC.mint(bob, 1000e6);
        mockUSDC.approve(address(artha), 1000e6);
        artha.supply(poolId1, 1000e6, bob);
        vm.stopPrank();

        vm.startPrank(alice);
        mockUSDC.approve(address(artha), 1000e6);
        artha.supply(poolId1, 1000e6, alice);

        uint256 shares = artha.supplies(poolId1, alice);

        artha.withdraw(poolId1, shares, alice, alice);
        assertEq(artha.supplies(poolId1, alice), 0);
    }

    function test_supplyCollateral() public {
        vm.startPrank(alice);
        IERC721(address(ip1)).approve(address(artha), 1);
        artha.supplyCollateral(poolId1, 1, alice);
    }

    function test_withdrawCollateral() public {
        vm.startPrank(alice);
        IERC721(address(ip1)).approve(address(artha), 1);
        artha.supplyCollateral(poolId1, 1, alice);

        artha.withdrawCollateral(poolId1, 1, alice, alice);
    }

    function test_borrow() public {
        // Bob supply
        vm.startPrank(bob);
        mockUSDC.mint(bob, 1000e6);
        mockUSDC.approve(address(artha), 1000e6);
        artha.supply(poolId1, 1000e6, bob);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC721(address(ip1)).approve(address(artha), 1);
        artha.supplyCollateral(poolId1, 1, alice);
        artha.borrow(poolId1, 1, 10e6, alice, alice);
    }

    function test_repay() public {
        // Bob supply
        vm.startPrank(bob);
        mockUSDC.mint(bob, 1000e6);
        mockUSDC.approve(address(artha), 1000e6);
        artha.supply(poolId1, 1000e6, bob);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC721(address(ip1)).approve(address(artha), 1);
        artha.supplyCollateral(poolId1, 1, alice);
        artha.borrow(poolId1, 1, 10e6, alice, alice);

        mockUSDC.mint(alice, 100e6);
        mockUSDC.approve(address(artha), 100e6);
        artha.repay(poolId1, 1, 5e6, alice);
    }
}
