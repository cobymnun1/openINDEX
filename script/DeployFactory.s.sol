// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/OpenINDEX.sol";
import "../src/OpenINDEXFactory.sol";

contract DeployFactory is Script {
    function run() external returns (OpenINDEXFactory factory) {
        address usdc = vm.envAddress("USDC_ADDRESS");
        vm.startBroadcast();
        factory = new OpenINDEXFactory(usdc, keccak256(type(OpenINDEX).creationCode));
        vm.stopBroadcast();
    }
}
