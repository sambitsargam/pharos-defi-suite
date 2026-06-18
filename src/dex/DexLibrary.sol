// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IDexFactoryFull, IDexPair} from "./IDex.sol";

/// @title DexLibrary
/// @notice Pricing math for the constant-product AMM (quote, amounts in/out, multi-hop).
library DexLibrary {
    function sortTokens(address a, address b) internal pure returns (address t0, address t1) {
        require(a != b, "DEX: IDENTICAL_ADDRESSES");
        (t0, t1) = a < b ? (a, b) : (b, a);
        require(t0 != address(0), "DEX: ZERO_ADDRESS");
    }

    function getReserves(address factory, address a, address b)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address t0,) = sortTokens(a, b);
        address pair = IDexFactoryFull(factory).getPair(a, b);
        if (pair == address(0)) return (0, 0);
        (uint112 r0, uint112 r1,) = IDexPair(pair).getReserves();
        (reserveA, reserveB) = a == t0 ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        internal
        pure
        returns (uint256 amountB)
    {
        require(amountA > 0, "DEX: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "DEX: INSUFFICIENT_LIQUIDITY");
        amountB = amountA * reserveB / reserveA;
    }

    /// @dev 0.30% fee constant-product output.
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "DEX: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "DEX: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "DEX: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "DEX: INSUFFICIENT_LIQUIDITY");
        amountIn = (reserveIn * amountOut * 1000) / ((reserveOut - amountOut) * 997) + 1;
    }

    function getAmountsOut(address factory, uint256 amountIn, address[] memory path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "DEX: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 rIn, uint256 rOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], rIn, rOut);
        }
    }

    function getAmountsIn(address factory, uint256 amountOut, address[] memory path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "DEX: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 rIn, uint256 rOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], rIn, rOut);
        }
    }
}
