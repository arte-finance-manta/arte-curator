// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MockCuratorFactory} from "../src/mocks/MockCuratorFactory.sol";

contract MockCuratorScript is Script {
    MockCuratorFactory public mockCuratorFactory;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        mockCuratorFactory = new MockCuratorFactory(0xD3Ec43F60E2AC1517c4DD80C0A23Ad8d902EAF0F);

        console.log("MockCuratorFactory deployed at", address(mockCuratorFactory));

        vm.stopBroadcast();
    }
}
