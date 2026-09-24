pragma solidity ^0.8.24;

import {IERC721Errors} from "../interfaces/IERC6093.sol";

abstract contract IndexOwnerId {
    string private _name;
    string private _symbol;
    string private _iconURI;
    mapping(uint256 tokenId => address) private _owners;

    constructor(string memory indexName, string memory symbol_, string memory iconURI_) {
        _name = string.concat(indexName, "OwnershipNFT");
        _symbol = symbol_;
        _iconURI = iconURI_;
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert IERC721Errors.ERC721NonexistentToken(tokenId);
        return owner;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        ownerOf(tokenId);
        return string.concat("data:application/json,{\"name\":\"", _name, "\",\"image\":\"", _iconURI, "\"}");
    }

    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) revert IERC721Errors.ERC721InvalidReceiver(address(0));
        if (_owners[tokenId] != address(0)) revert IERC721Errors.ERC721InvalidSender(address(0));
        _owners[tokenId] = to;
    }

    function _burn(uint256 tokenId) internal {
        ownerOf(tokenId);
        delete _owners[tokenId];
    }
}
