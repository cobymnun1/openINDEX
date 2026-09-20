// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/OpenINDEX.sol";
import "../src/OpenINDEXFactory.sol";

contract CreateSepoliaTestBasket is Script {
    function run() external returns (address basket) {
        OpenINDEXFactory factory = OpenINDEXFactory(vm.envAddress("FACTORY_ADDRESS"));
        address weth = vm.envAddress("WETH_ADDRESS");
        address signer = vm.envAddress("ROUTE_SIGNER");

        address[] memory tokens = new address[](1);
        tokens[0] = weth;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10_000;

        vm.startBroadcast();
        basket = factory.createBasket(
            "openINDEX Sepolia Test",
            "oINDEX",
            "base-sepolia://openindex-weth-test",
            tokens,
            weights,
            signer,
            type(OpenINDEX).creationCode
        );
        vm.stopBroadcast();
    }
}
