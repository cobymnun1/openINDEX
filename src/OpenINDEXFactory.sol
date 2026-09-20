// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./OpenINDEXManagerNFT.sol";

/// @notice Permissionless factory for generic openINDEX baskets.
contract OpenINDEXFactory {
    address public immutable usdc;
    bytes32 public immutable basketCreationCodeHash;
    uint256 public basketCount;
    mapping(uint256 => address) public basketAt;

    error ZeroAddress();
    error EmptyMetadata();
    error EmptyCreationCode();
    error InvalidCreationCode();
    error BasketDeploymentFailed();

    event BasketCreated(
        uint256 indexed basketId,
        address indexed basket,
        address indexed manager,
        address routeSigner,
        string name,
        string symbol
    );

    constructor(
        address usdc_,
        bytes32 basketCreationCodeHash_
    ) {
        if (usdc_ == address(0) || basketCreationCodeHash_ == bytes32(0)) revert ZeroAddress();
        usdc = usdc_;
        basketCreationCodeHash = basketCreationCodeHash_;
    }

    function createBasket(
        string calldata name,
        string calldata symbol,
        string calldata metadataURI,
        address[] calldata tokens,
        uint256[] calldata weights,
        address routeSigner,
        bytes calldata basketCreationCode
    ) external returns (address basket) {
        if (bytes(name).length == 0 || bytes(symbol).length == 0) revert EmptyMetadata();
        if (basketCreationCode.length == 0) revert EmptyCreationCode();
        if (!_isCanonicalCreationCode(basketCreationCode)) revert InvalidCreationCode();
        OpenINDEXManagerNFT managerNFT =
            new OpenINDEXManagerNFT(string.concat(name, " Manager"), string.concat(symbol, "-M"), address(this));
        uint256 managerTokenId = managerNFT.mint(msg.sender);
        bytes memory initCode = abi.encodePacked(
            basketCreationCode,
            abi.encode(
                name, symbol, metadataURI, tokens, weights, address(managerNFT), managerTokenId, routeSigner, usdc
            )
        );
        assembly {
            basket := create(0, add(initCode, 0x20), mload(initCode))
        }
        if (basket == address(0)) revert BasketDeploymentFailed();
        uint256 id = basketCount++;
        basketAt[id] = basket;
        emit BasketCreated(id, basket, msg.sender, routeSigner, name, symbol);
    }

    function _isCanonicalCreationCode(
        bytes calldata creationCode
    ) internal view returns (bool) {
        return keccak256(creationCode) == basketCreationCodeHash;
    }
}
