// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title  MultiToken
/// @notice ERC1155 multi-token with per-id supply tracking and owner minting.
contract MultiToken is ERC1155Supply, Ownable {
    string public name;
    string public symbol;

    constructor(string memory name_, string memory symbol_, string memory uri_, address owner_)
        ERC1155(uri_)
        Ownable(owner_)
    {
        name = name_;
        symbol = symbol_;
    }

    function mint(address to, uint256 id, uint256 amount, bytes calldata data) external onlyOwner {
        _mint(to, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    function setURI(string calldata newuri) external onlyOwner {
        _setURI(newuri);
    }
}
