// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title  OTCSwap
/// @notice Trustless peer-to-peer token swaps. A maker escrows the token they're selling and
///         names the token/amount they want; anyone (or a named taker) atomically fills it.
contract OTCSwap is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Order {
        address maker;
        address tokenSell;
        uint256 amountSell;
        address tokenBuy;
        uint256 amountBuy;
        address taker; // address(0) = open to anyone
        bool active;
    }

    mapping(uint256 => Order) public orders;
    uint256 public nextOrderId;

    event OrderCreated(uint256 indexed id, address indexed maker, address tokenSell, uint256 amountSell, address tokenBuy, uint256 amountBuy);
    event OrderFilled(uint256 indexed id, address indexed taker);
    event OrderCancelled(uint256 indexed id);

    /// @notice Create an order, escrowing `amountSell` of `tokenSell`.
    function createOrder(
        address tokenSell,
        uint256 amountSell,
        address tokenBuy,
        uint256 amountBuy,
        address taker
    ) external nonReentrant returns (uint256 id) {
        require(amountSell > 0 && amountBuy > 0, "zero amount");
        require(tokenSell != tokenBuy, "same token");
        id = nextOrderId++;
        orders[id] = Order({
            maker: msg.sender,
            tokenSell: tokenSell,
            amountSell: amountSell,
            tokenBuy: tokenBuy,
            amountBuy: amountBuy,
            taker: taker,
            active: true
        });
        IERC20(tokenSell).safeTransferFrom(msg.sender, address(this), amountSell);
        emit OrderCreated(id, msg.sender, tokenSell, amountSell, tokenBuy, amountBuy);
    }

    /// @notice Fill an order: pay `amountBuy` to the maker, receive the escrowed `amountSell`.
    function fillOrder(uint256 id) external nonReentrant {
        Order storage o = orders[id];
        require(o.active, "inactive");
        require(o.taker == address(0) || o.taker == msg.sender, "not allowed taker");
        o.active = false;
        IERC20(o.tokenBuy).safeTransferFrom(msg.sender, o.maker, o.amountBuy);
        IERC20(o.tokenSell).safeTransfer(msg.sender, o.amountSell);
        emit OrderFilled(id, msg.sender);
    }

    /// @notice Maker cancels and reclaims the escrowed tokens.
    function cancelOrder(uint256 id) external nonReentrant {
        Order storage o = orders[id];
        require(o.active && msg.sender == o.maker, "cannot cancel");
        o.active = false;
        IERC20(o.tokenSell).safeTransfer(o.maker, o.amountSell);
        emit OrderCancelled(id);
    }
}
