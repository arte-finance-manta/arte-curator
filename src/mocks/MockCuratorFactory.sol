// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MockCurator} from "./MockCurator.sol";

interface IArtha {
    function isPoolExist(bytes32 id) external view returns (bool);
}

contract MockCuratorFactory {
    error InvalidLength(uint256 poolsLength, uint256 allocationsLength);
    error InvalidAllocation(bytes32 pool, uint256 allocation);
    error InvalidPool(bytes32 pool);

    event CuratorDeployed(
        address indexed curator, string name, string symbol, address asset, bytes32[] pools, uint256[] allocations
    );

    uint256 public constant ALLOCATION_SCALED = 1e18;

    address public immutable artha;

    constructor(address _artha) {
        artha = _artha;
    }

    function deployCurator(
        string calldata _name,
        string calldata _symbol,
        address _asset,
        bytes32[] memory pools,
        uint256[] memory allocations
    ) public returns (address curator) {
        if (pools.length == 0 || allocations.length == 0) revert InvalidLength(pools.length, allocations.length);
        if (pools.length != allocations.length) revert InvalidLength(pools.length, allocations.length);

        for (uint256 i = 0; i < pools.length; i++) {
            if (allocations[i] == 0) revert InvalidAllocation(pools[i], allocations[i]);
            if (allocations[i] > ALLOCATION_SCALED) revert InvalidAllocation(pools[i], allocations[i]);
            if (!IArtha(artha).isPoolExist(pools[i])) revert InvalidPool(pools[i]);
        }

        curator = address(new MockCurator(_name, _symbol, _asset));

        emit CuratorDeployed(curator, _name, _symbol, _asset, pools, allocations);
    }
}
