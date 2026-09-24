pragma solidity ^0.8.24;

import "./TokenIssue.sol";
import "./NFTIssue.sol";

contract IndexToken is ERC20 {
    string public iconURI;

    constructor(string memory indexName, address recipient, string memory iconURI_) ERC20(indexName, indexName) {
        iconURI = iconURI_;
        _mint(recipient, 100_000 ether);
    }
}

contract IndexOwner is IndexOwnerId {
    constructor(string memory indexName, address recipient, string memory iconURI_)
        IndexOwnerId(indexName, "INDEX-O", iconURI_)
    {
        _mint(recipient, 0);
    }
}

struct IndexAsset {
    address token;
    uint256 weight;
}

contract IndexFactory {
    error InvalidIndexAsset();
    error InvalidWeights();

    event IndexCreated(address indexed creator, address indexed token, address indexed ownerId, IndexAsset[] assets);

    function createIndex(string calldata indexName, string calldata iconURI, IndexAsset[] calldata assets)
        external
        returns (address token, address ownerId)
    {
        _validateAssets(assets);
        token = address(new IndexToken(indexName, msg.sender, iconURI));
        ownerId = address(new IndexOwner(indexName, msg.sender, iconURI));
        emit IndexCreated(msg.sender, token, ownerId, assets);
    }

    function _validateAssets(IndexAsset[] calldata assets) private view {
        if (assets.length < 2) revert InvalidIndexAsset();

        uint256 totalWeight;
        for (uint256 i; i < assets.length; ++i) {
            IndexAsset calldata asset = assets[i];
            if (asset.token == address(0) || asset.token.code.length == 0 || asset.weight == 0) {
                revert InvalidIndexAsset();
            }
            totalWeight += asset.weight;
        }

        if (totalWeight != 100) revert InvalidWeights();
    }
}
