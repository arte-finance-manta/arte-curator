// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MockCuratorFactory} from "../src/mocks/MockCuratorFactory.sol";

contract MockCuratorScript is Script {
    MockCuratorFactory public mockCuratorFactory;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        mockCuratorFactory = new MockCuratorFactory(0x34d438480F557592AB8aCf192D16C4C871401438);

        console.log("MockCuratorFactory deployed at", address(mockCuratorFactory));

        vm.stopBroadcast();
    }
}
