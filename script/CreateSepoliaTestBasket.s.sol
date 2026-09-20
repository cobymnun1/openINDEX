// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/OpenINDEX.sol";
import "../src/OpenINDEXFactory.sol";

contract CreateSepoliaTestBasket is Script {
    function run() external returns (address basket) {
        OpenINDEXFactory factory = OpenINDEXFactory(vm.envAddress("FACTORY_ADDRESS"));
        address weth = vm.envAddress("WETH_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address signer = vm.envAddress("ROUTE_SIGNER");

        address[] memory tokens = new address[](2);
        tokens[0] = weth;
        tokens[1] = usdc;
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000;
        weights[1] = 5000;

        vm.startBroadcast();
        basket = factory.createBasket(
            "openINDEX Sepolia WETH USDC Test",
            "oINDEX",
            "base-sepolia://openindex-weth-usdc-test",
            tokens,
            weights,
            signer,
            type(OpenINDEX).creationCode
        );
        vm.stopBroadcast();
    }
}
