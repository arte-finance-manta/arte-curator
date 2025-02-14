// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IArtha, Pool, Id, PoolParams} from "../src/core/interfaces/IArtha.sol";
import {ArthaCurator} from "./ArthaCurator.sol";

contract ArthaCuratorFactory {
    error InvalidLength(uint256 poolsLength, uint256 allocationsLength);
    error InvalidAllocation(bytes32 pool, uint256 allocation);
    error InvalidPool(bytes32 pool);

    event CuratorDeployed(
        address indexed curator, address indexed artha, address indexed asset, bytes32[] pools, uint256[] allocations
    );

    uint256 public constant ALLOCATION_SCALED = 1e18;

    address public immutable artha;

    constructor(address _artha) {
        artha = _artha;
    }

    function deployCurator(address _asset, bytes32[] memory pools, uint256[] memory allocations)
        public
        returns (address curator)
    {
        if (pools.length == 0 || allocations.length == 0) revert InvalidLength(pools.length, allocations.length);
        if (pools.length != allocations.length) revert InvalidLength(pools.length, allocations.length);

        for (uint256 i = 0; i < pools.length; i++) {
            if (allocations[i] == 0) revert InvalidAllocation(pools[i], allocations[i]);
            if (allocations[i] > ALLOCATION_SCALED) revert InvalidAllocation(pools[i], allocations[i]);

            (,,,,,,,,,, uint256 lastAccrued) = IArtha(artha).pools(Id.wrap(pools[i]));

            if (lastAccrued == 0) revert InvalidPool(pools[i]);
        }

        curator = address(new ArthaCurator(artha, _asset));

        emit CuratorDeployed(curator, artha, _asset, pools, allocations);
    }
}
