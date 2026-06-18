// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title  TokenSale
/// @notice Fixed-price IDO/presale. Buyers pay native PHRS and receive sale tokens at a fixed
///         rate, within a time window and an optional hard cap. Owner withdraws proceeds and
///         any unsold tokens after the sale.
contract TokenSale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public immutable tokensPerNative; // token (1e18) units per 1 PHRS, scaled by 1e18
    uint64 public immutable start;
    uint64 public immutable end;
    uint256 public immutable hardCap; // max native raised (0 = uncapped)
    uint256 public raised;

    event Purchased(address indexed buyer, uint256 nativeIn, uint256 tokensOut);

    constructor(
        address token_,
        uint256 tokensPerNative_,
        uint64 start_,
        uint64 end_,
        uint256 hardCap_,
        address owner_
    ) Ownable(owner_) {
        require(end_ > start_ && tokensPerNative_ > 0, "bad params");
        token = IERC20(token_);
        tokensPerNative = tokensPerNative_;
        start = start_;
        end = end_;
        hardCap = hardCap_;
    }

    function buy() public payable nonReentrant {
        require(block.timestamp >= start && block.timestamp <= end, "sale closed");
        require(msg.value > 0, "zero");
        require(hardCap == 0 || raised + msg.value <= hardCap, "hard cap reached");
        uint256 tokensOut = (msg.value * tokensPerNative) / 1e18;
        require(tokensOut > 0, "amount too small");
        raised += msg.value;
        token.safeTransfer(msg.sender, tokensOut);
        emit Purchased(msg.sender, msg.value, tokensOut);
    }

    receive() external payable {
        buy();
    }

    function withdrawProceeds(address payable to) external onlyOwner {
        (bool ok,) = to.call{value: address(this).balance}("");
        require(ok, "withdraw failed");
    }

    function withdrawUnsold(address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }
}
