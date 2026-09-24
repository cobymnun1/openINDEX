pragma solidity ^0.8.24;

import {IERC20} from "../interfaces/IERC20.sol";
import {IERC20Metadata} from "../interfaces/IERC20Metadata.sol";
import {Math} from "../utils/math/Math.sol";

interface IBasketView {
    function getConstituents() external view returns (address[] memory tokens, uint256[] memory weights);
}

contract Oindex {
    uint256 public constant BASIS_POINTS = 10_000;
    address public immutable keeper;

    error LengthMismatch();
    error InvalidWeights();
    error InvalidPrice();
    error InvalidDecimals();
    error NoUnderweightTokens();
    error Unauthorized();
    error NAVUnderflow();
    error SwapAmountOverflow();
    error InvalidVault();
    error InvalidToken();
    error EmptyBasket();

    constructor(address keeper_) {
        if (keeper_ == address(0)) revert Unauthorized();
        keeper = keeper_;
    }

    modifier onlyKeeper() {
        if (msg.sender != keeper) revert Unauthorized();
        _;
    }

    /// @dev Prices and deposit use 1e18-scaled quote units.
    ///      Prices represent the value of one whole token.
    function calculateSwapAmounts(address vault, uint256[] calldata prices, int256 navChange)
        external
        view
        onlyKeeper
        returns (int256[] memory swapAmounts)
    {
        if (vault == address(0) || vault.code.length == 0) revert InvalidVault();
        (address[] memory tokens, uint256[] memory targetWeights) = IBasketView(vault).getConstituents();
        uint256 length = tokens.length;
        if (length == 0) revert EmptyBasket();
        if (prices.length != length || targetWeights.length != length) revert LengthMismatch();

        uint256[] memory currentQuantities = new uint256[](length);
        uint256[] memory decs = new uint256[](length);
        uint256 totalWeight;
        uint256 currentNAV;
        uint256 newNAV;

        // Validate all inputs before calculating NAV.
        for (uint256 i; i < length; ++i) {
            if (tokens[i] == address(0) || tokens[i].code.length == 0) revert InvalidToken();
            if (prices[i] == 0) revert InvalidPrice();
            decs[i] = IERC20Metadata(tokens[i]).decimals();
            if (decs[i] > 77) revert InvalidDecimals();
            totalWeight += targetWeights[i];
        }

        if (totalWeight != BASIS_POINTS) revert InvalidWeights();

        // Read current holdings and calculate pre- and post-deposit NAV.
        uint256[] memory values = new uint256[](length);
        for (uint256 i; i < length; ++i) {
            currentQuantities[i] = IERC20(tokens[i]).balanceOf(vault);
            values[i] = Math.mulDiv(
                currentQuantities[i],
                prices[i],
                10 ** decs[i]
            );
            currentNAV += values[i];
        }

        if (navChange >= 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            newNAV = currentNAV + uint256(navChange);
        } else {
            if (navChange == type(int256).min) revert NAVUnderflow();
            // forge-lint: disable-next-line(unsafe-typecast)
            uint256 decrease = uint256(-navChange);
            if (decrease > currentNAV) revert NAVUnderflow();
            newNAV = currentNAV - decrease;
        }
        
        swapAmounts = new int256[](length);
        if (navChange == 0) return swapAmounts;

        bool isDeposit = navChange > 0;
        // navChange == int256.min is rejected above.
        uint256 flow;
        if (isDeposit) {
            // forge-lint: disable-next-line(unsafe-typecast)
            flow = uint256(navChange);
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            flow = uint256(-navChange);
        }
        uint256[] memory gap = new uint256[](length);
        uint256 totalGap;

        for (uint256 i; i < length; ++i) {
            uint256 targetValue = Math.mulDiv(newNAV, targetWeights[i], BASIS_POINTS);
            gap[i] = isDeposit
                ? (targetValue > values[i] ? targetValue - values[i] : 0)
                : (values[i] > targetValue ? values[i] - targetValue : 0);
            totalGap += gap[i];
        }

        if (totalGap == 0) revert NoUnderweightTokens();

        for (uint256 i; i < length; ++i) {
            if (gap[i] == 0) continue;

            uint256 value = Math.mulDiv(flow, gap[i], totalGap);
            uint256 quantity = Math.mulDiv(
                value,
                10 ** decs[i],
                prices[i]
            );
            if (quantity > uint256(type(int256).max)) revert SwapAmountOverflow();

            if (isDeposit) {
                // forge-lint: disable-next-line(unsafe-typecast)
                swapAmounts[i] = int256(quantity);
            } else {
                // forge-lint: disable-next-line(unsafe-typecast)
                swapAmounts[i] = -int256(quantity);
            }
        }
    }
}
