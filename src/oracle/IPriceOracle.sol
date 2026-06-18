// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Price oracle interface. Returns the USD price of one whole token, scaled to 1e18.
interface IPriceOracle {
    function getPrice(address token) external view returns (uint256 priceE18);
}
