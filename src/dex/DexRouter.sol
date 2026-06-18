// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDexFactoryFull, IDexPair, IWrappedNative} from "./IDex.sol";
import {DexLibrary} from "./DexLibrary.sol";

/// @title  DexRouter
/// @notice User-facing entry point for the AMM: add/remove liquidity and swap tokens,
///         including native PHRS via the wrapped-native (WPHRS) token.
contract DexRouter {
    using SafeERC20 for IERC20;

    address public immutable factory;
    address public immutable WNATIVE;

    modifier ensure(uint256 deadline) {
        require(block.timestamp <= deadline, "DEX: EXPIRED");
        _;
    }

    constructor(address factory_, address wnative_) {
        factory = factory_;
        WNATIVE = wnative_;
    }

    receive() external payable {
        require(msg.sender == WNATIVE, "DEX: only WNATIVE");
    }

    /*//////////////////////////////////////////////////////////////
                              LIQUIDITY
    //////////////////////////////////////////////////////////////*/

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        if (IDexFactoryFull(factory).getPair(tokenA, tokenB) == address(0)) {
            IDexFactoryFull(factory).createPair(tokenA, tokenB);
        }
        (uint256 rA, uint256 rB) = DexLibrary.getReserves(factory, tokenA, tokenB);
        if (rA == 0 && rB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 bOpt = DexLibrary.quote(amountADesired, rA, rB);
            if (bOpt <= amountBDesired) {
                require(bOpt >= amountBMin, "DEX: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, bOpt);
            } else {
                uint256 aOpt = DexLibrary.quote(amountBDesired, rB, rA);
                assert(aOpt <= amountADesired);
                require(aOpt >= amountAMin, "DEX: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (aOpt, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) =
            _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = IDexFactoryFull(factory).getPair(tokenA, tokenB);
        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);
        liquidity = IDexPair(pair).mint(to);
    }

    function addLiquidityNative(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline
    )
        external
        payable
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountNative, uint256 liquidity)
    {
        (amountToken, amountNative) = _addLiquidity(
            token, WNATIVE, amountTokenDesired, msg.value, amountTokenMin, amountNativeMin
        );
        address pair = IDexFactoryFull(factory).getPair(token, WNATIVE);
        IERC20(token).safeTransferFrom(msg.sender, pair, amountToken);
        IWrappedNative(WNATIVE).deposit{value: amountNative}();
        IERC20(WNATIVE).safeTransfer(pair, amountNative);
        liquidity = IDexPair(pair).mint(to);
        if (msg.value > amountNative) {
            (bool ok,) = payable(msg.sender).call{value: msg.value - amountNative}("");
            require(ok, "DEX: refund failed");
        }
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = IDexFactoryFull(factory).getPair(tokenA, tokenB);
        IERC20(pair).safeTransferFrom(msg.sender, pair, liquidity);
        (uint256 amount0, uint256 amount1) = IDexPair(pair).burn(to);
        (address t0,) = DexLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == t0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "DEX: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "DEX: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityNative(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountToken, uint256 amountNative) {
        (amountToken, amountNative) = removeLiquidity(
            token, WNATIVE, liquidity, amountTokenMin, amountNativeMin, address(this), deadline
        );
        IERC20(token).safeTransfer(to, amountToken);
        IWrappedNative(WNATIVE).withdraw(amountNative);
        (bool ok,) = payable(to).call{value: amountNative}("");
        require(ok, "DEX: native transfer failed");
    }

    /*//////////////////////////////////////////////////////////////
                                SWAPS
    //////////////////////////////////////////////////////////////*/

    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address t0,) = DexLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == t0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? IDexFactoryFull(factory).getPair(output, path[i + 2])
                : _to;
            IDexPair(IDexFactoryFull(factory).getPair(input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = DexLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "DEX: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(
            msg.sender, IDexFactoryFull(factory).getPair(path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = DexLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "DEX: EXCESSIVE_INPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(
            msg.sender, IDexFactoryFull(factory).getPair(path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactNativeForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WNATIVE, "DEX: INVALID_PATH");
        amounts = DexLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "DEX: INSUFFICIENT_OUTPUT_AMOUNT");
        IWrappedNative(WNATIVE).deposit{value: amounts[0]}();
        IERC20(WNATIVE).safeTransfer(IDexFactoryFull(factory).getPair(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactTokensForNative(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WNATIVE, "DEX: INVALID_PATH");
        amounts = DexLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "DEX: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(
            msg.sender, IDexFactoryFull(factory).getPair(path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        uint256 out = amounts[amounts.length - 1];
        IWrappedNative(WNATIVE).withdraw(out);
        (bool ok,) = payable(to).call{value: out}("");
        require(ok, "DEX: native transfer failed");
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory)
    {
        return DexLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory)
    {
        return DexLibrary.getAmountsIn(factory, amountOut, path);
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        external
        pure
        returns (uint256)
    {
        return DexLibrary.quote(amountA, reserveA, reserveB);
    }
}
