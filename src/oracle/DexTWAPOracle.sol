// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IDexPairTWAP {
    function getReserves() external view returns (uint112, uint112, uint32);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/// @title  DexTWAPOracle
/// @notice Manipulation-resistant time-weighted average price from a DexPair's cumulative
///         price accumulators. Call {update} once per period, then {consult}.
contract DexTWAPOracle {
    uint256 public immutable period;
    IDexPairTWAP public immutable pair;
    address public immutable token0;
    address public immutable token1;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint32 public blockTimestampLast;
    uint224 public price0Average; // UQ112x112
    uint224 public price1Average; // UQ112x112

    constructor(address pair_, uint256 period_) {
        pair = IDexPairTWAP(pair_);
        token0 = IDexPairTWAP(pair_).token0();
        token1 = IDexPairTWAP(pair_).token1();
        price0CumulativeLast = IDexPairTWAP(pair_).price0CumulativeLast();
        price1CumulativeLast = IDexPairTWAP(pair_).price1CumulativeLast();
        (,, blockTimestampLast) = IDexPairTWAP(pair_).getReserves();
        period = period_;
    }

    /// @notice Refresh the averages. Must be called at least once per `period`.
    function update() external {
        uint256 p0 = pair.price0CumulativeLast();
        uint256 p1 = pair.price1CumulativeLast();
        (,, uint32 blockTimestamp) = pair.getReserves();
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast;
        }
        require(timeElapsed >= period, "TWAP: period not elapsed");
        unchecked {
            price0Average = uint224((p0 - price0CumulativeLast) / timeElapsed);
            price1Average = uint224((p1 - price1CumulativeLast) / timeElapsed);
        }
        price0CumulativeLast = p0;
        price1CumulativeLast = p1;
        blockTimestampLast = blockTimestamp;
    }

    /// @notice Convert `amountIn` of `token` into the other token at the average price.
    function consult(address token, uint256 amountIn) external view returns (uint256 amountOut) {
        if (token == token0) {
            amountOut = (uint256(price0Average) * amountIn) >> 112;
        } else {
            require(token == token1, "TWAP: invalid token");
            amountOut = (uint256(price1Average) * amountIn) >> 112;
        }
    }
}
