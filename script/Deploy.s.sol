// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Glue} from "src/Glue.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        Glue glue = new Glue(vm.envAddress("FEE_TOKEN"));
        console.log("GLUE_CONTRACT: %s", address(glue));
        vm.stopBroadcast();
    }
}
