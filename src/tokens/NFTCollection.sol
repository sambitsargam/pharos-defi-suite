// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title  NFTCollection
/// @notice Enumerable ERC721 with a paid public mint, max supply, and owner controls.
contract NFTCollection is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 public immutable maxSupply;
    uint256 public mintPrice;
    string private _base;
    uint256 private _nextId;

    event Minted(address indexed to, uint256 indexed tokenId);

    error MaxSupplyReached();
    error WrongPrice(uint256 sent, uint256 required);

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 maxSupply_,
        uint256 mintPrice_,
        address owner_
    ) ERC721(name_, symbol_) Ownable(owner_) {
        _base = baseURI_;
        maxSupply = maxSupply_;
        mintPrice = mintPrice_;
    }

    /// @notice Public mint. Send exactly `mintPrice` native PHRS.
    function mint() external payable returns (uint256 tokenId) {
        if (msg.value != mintPrice) revert WrongPrice(msg.value, mintPrice);
        if (maxSupply != 0 && _nextId >= maxSupply) revert MaxSupplyReached();
        tokenId = _nextId++;
        _safeMint(msg.sender, tokenId);
        emit Minted(msg.sender, tokenId);
    }

    /// @notice Owner free-mint (airdrops, team).
    function ownerMint(address to) external onlyOwner returns (uint256 tokenId) {
        if (maxSupply != 0 && _nextId >= maxSupply) revert MaxSupplyReached();
        tokenId = _nextId++;
        _safeMint(to, tokenId);
        emit Minted(to, tokenId);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _base = baseURI_;
    }

    function withdraw(address to) external onlyOwner {
        (bool ok,) = payable(to).call{value: address(this).balance}("");
        require(ok, "withdraw failed");
    }

    function _baseURI() internal view override returns (string memory) {
        return _base;
    }
}
