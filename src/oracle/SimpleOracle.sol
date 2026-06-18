// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceOracle} from "./IPriceOracle.sol";

/// @title  SimpleOracle
/// @notice Owner-administered price feed (USD, 1e18). Suitable for testnets and as a
///         fallback. For production, point consumers at a TWAP or Chainlink-style feed.
contract SimpleOracle is IPriceOracle, Ownable {
    mapping(address => uint256) private _prices;
    mapping(address => uint256) public updatedAt;

    event PriceSet(address indexed token, uint256 priceE18);

    constructor(address owner_) Ownable(owner_) {}

    function setPrice(address token, uint256 priceE18) public onlyOwner {
        _prices[token] = priceE18;
        updatedAt[token] = block.timestamp;
        emit PriceSet(token, priceE18);
    }

    function setPrices(address[] calldata tokens, uint256[] calldata pricesE18) external onlyOwner {
        require(tokens.length == pricesE18.length, "length mismatch");
        for (uint256 i; i < tokens.length; i++) {
            setPrice(tokens[i], pricesE18[i]);
        }
    }

    function getPrice(address token) external view returns (uint256) {
        uint256 p = _prices[token];
        require(p > 0, "price unset");
        return p;
    }
}
