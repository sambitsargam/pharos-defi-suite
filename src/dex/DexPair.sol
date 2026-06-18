// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DexMath, UQ112x112} from "../libraries/DexMath.sol";

interface IDexFactory {
    function feeTo() external view returns (address);
}

interface IDexCallee {
    function dexCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

/// @title  DexPair
/// @notice Constant-product (x*y=k) AMM pair with 0.30% fee and TWAP price accumulators.
///         The LP token is this contract itself (ERC20). Deployed by DexFactory.
contract DexPair is ERC20 {
    using UQ112x112 for uint224;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    address public factory;
    address public token0;
    address public token1;

    uint112 private _reserve0;
    uint112 private _reserve1;
    uint32 private _blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    uint256 private _unlocked = 1;

    modifier lock() {
        require(_unlocked == 1, "DEX: LOCKED");
        _unlocked = 0;
        _;
        _unlocked = 1;
    }

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() ERC20("Pharos DEX LP", "PHRS-LP") {
        factory = msg.sender;
    }

    /// @notice Called once by the factory right after deployment.
    function initialize(address t0, address t1) external {
        require(msg.sender == factory, "DEX: FORBIDDEN");
        token0 = t0;
        token1 = t1;
    }

    function getReserves() public view returns (uint112 r0, uint112 r1, uint32 ts) {
        return (_reserve0, _reserve1, _blockTimestampLast);
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool ok, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "DEX: TRANSFER_FAILED");
    }

    function _updateReserves(uint256 balance0, uint256 balance1, uint112 r0, uint112 r1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "DEX: OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        unchecked {
            uint32 timeElapsed = blockTimestamp - _blockTimestampLast;
            if (timeElapsed > 0 && r0 != 0 && r1 != 0) {
                price0CumulativeLast += uint256(UQ112x112.encode(r1).uqdiv(r0)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(r0).uqdiv(r1)) * timeElapsed;
            }
        }
        _reserve0 = uint112(balance0);
        _reserve1 = uint112(balance1);
        _blockTimestampLast = blockTimestamp;
        emit Sync(_reserve0, _reserve1);
    }

    /// @notice Mint LP tokens to `to` for the tokens that were transferred in.
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 r0, uint112 r1,) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - r0;
        uint256 amount1 = balance1 - r1;

        uint256 supply = totalSupply();
        if (supply == 0) {
            liquidity = DexMath.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(DEAD, MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY
        } else {
            liquidity = DexMath.min(amount0 * supply / r0, amount1 * supply / r1);
        }
        require(liquidity > 0, "DEX: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);
        _updateReserves(balance0, balance1, r0, r1);
        emit Mint(msg.sender, amount0, amount1);
    }

    /// @notice Burn LP tokens held by this contract and send underlying to `to`.
    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint112 r0, uint112 r1,) = getReserves();
        address t0 = token0;
        address t1 = token1;
        uint256 balance0 = IERC20(t0).balanceOf(address(this));
        uint256 balance1 = IERC20(t1).balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));

        uint256 supply = totalSupply();
        amount0 = liquidity * balance0 / supply;
        amount1 = liquidity * balance1 / supply;
        require(amount0 > 0 && amount1 > 0, "DEX: INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        _safeTransfer(t0, to, amount0);
        _safeTransfer(t1, to, amount1);
        balance0 = IERC20(t0).balanceOf(address(this));
        balance1 = IERC20(t1).balanceOf(address(this));
        _updateReserves(balance0, balance1, r0, r1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /// @notice Swap out `amount0Out`/`amount1Out` to `to`; caller must have sent input first.
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data)
        external
        lock
    {
        require(amount0Out > 0 || amount1Out > 0, "DEX: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 r0, uint112 r1,) = getReserves();
        require(amount0Out < r0 && amount1Out < r1, "DEX: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        {
            address t0 = token0;
            address t1 = token1;
            require(to != t0 && to != t1, "DEX: INVALID_TO");
            if (amount0Out > 0) _safeTransfer(t0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(t1, to, amount1Out);
            if (data.length > 0) IDexCallee(to).dexCall(msg.sender, amount0Out, amount1Out, data);
            balance0 = IERC20(t0).balanceOf(address(this));
            balance1 = IERC20(t1).balanceOf(address(this));
        }
        uint256 amount0In = balance0 > r0 - amount0Out ? balance0 - (r0 - amount0Out) : 0;
        uint256 amount1In = balance1 > r1 - amount1Out ? balance1 - (r1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "DEX: INSUFFICIENT_INPUT_AMOUNT");
        {
            // 0.30% fee: balanceAdjusted = balance*1000 - amountIn*3
            uint256 b0Adj = balance0 * 1000 - amount0In * 3;
            uint256 b1Adj = balance1 * 1000 - amount1In * 3;
            require(b0Adj * b1Adj >= uint256(r0) * uint256(r1) * (1000 ** 2), "DEX: K");
        }
        _updateReserves(balance0, balance1, r0, r1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /// @notice Force balances to match reserves (sends surplus to `to`).
    function skim(address to) external lock {
        address t0 = token0;
        address t1 = token1;
        _safeTransfer(t0, to, IERC20(t0).balanceOf(address(this)) - _reserve0);
        _safeTransfer(t1, to, IERC20(t1).balanceOf(address(this)) - _reserve1);
    }

    /// @notice Force reserves to match balances.
    function sync() external lock {
        _updateReserves(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            _reserve0,
            _reserve1
        );
    }
}
