// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DexPair} from "./DexPair.sol";

/// @title  DexFactory
/// @notice Deploys and registers constant-product AMM pairs (one per token pair).
contract DexFactory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    constructor(address feeToSetter_) {
        feeToSetter = feeToSetter_;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /// @notice Create the pair for (tokenA, tokenB) if it does not already exist.
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "DEX: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "DEX: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "DEX: PAIR_EXISTS");

        DexPair p = new DexPair();
        p.initialize(token0, token1);
        pair = address(p);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address feeTo_) external {
        require(msg.sender == feeToSetter, "DEX: FORBIDDEN");
        feeTo = feeTo_;
    }

    function setFeeToSetter(address feeToSetter_) external {
        require(msg.sender == feeToSetter, "DEX: FORBIDDEN");
        feeToSetter = feeToSetter_;
    }
}
