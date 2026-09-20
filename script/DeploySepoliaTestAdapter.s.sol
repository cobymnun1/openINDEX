// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/OpenINDEX.sol";
import "../src/OpenINDEXExecutionAdapter.sol";

interface IERC20Test {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function transfer(
        address to,
        uint256 amount
    ) external returns (bool);
}

contract OpenINDEXTestVenue {
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address recipient
    ) external {
        require(IERC20Test(tokenIn).transferFrom(msg.sender, address(this), amountIn));
        require(IERC20Test(tokenOut).transfer(recipient, amountOut));
    }
}

contract DeploySepoliaTestAdapter is Script {
    function run() external returns (address venue, address adapter) {
        OpenINDEX basket = OpenINDEX(payable(vm.envAddress("BASKET_ADDRESS")));

        vm.startBroadcast();
        venue = address(new OpenINDEXTestVenue());
        adapter = address(new OpenINDEXExecutionAdapter(venue));
        basket.setRouter(adapter, true);
        vm.stopBroadcast();
    }
}
