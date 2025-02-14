// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ArthaCuratorFactory} from "../src/ArthaCuratorFactory.sol";
import {ArthaCurator} from "../src/ArthaCurator.sol";
import {MockIrm} from "../src/core/mocks/MockIrm.sol";
import {MockUSDC} from "../src/core/mocks/MockUSDC.sol";
import {Artha} from "../src/core/Artha.sol";
import {Id, PoolParams} from "../src/core/interfaces/IArtha.sol";

contract ArthaCuratorFactoryTest is Test {
    ArthaCuratorFactory public factory;
    Artha public artha;
    MockIrm public mockIrm;
    MockUSDC public mockUSDC;

    address public owner = makeAddr("owner");
    address public asset = makeAddr("asset");

    Id public poolId1;
    Id public poolId2;
    Id public poolId3;

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

        factory = new ArthaCuratorFactory(address(artha));

        vm.stopPrank();
    }

    function test_deployCurator() public {
        vm.startPrank(owner);

        bytes32[] memory pools = new bytes32[](3);
        pools[0] = Id.unwrap(poolId1);
        pools[1] = Id.unwrap(poolId2);
        pools[2] = Id.unwrap(poolId3);

        uint256[] memory allocations = new uint256[](3);
        allocations[0] = 0.4e18;
        allocations[1] = 0.35e18;
        allocations[2] = 0.25e18;

        address curator = factory.deployCurator(address(mockUSDC), pools, allocations);

        assertTrue(curator != address(0), "Curator not deployed");

        vm.stopPrank();
    }
}
