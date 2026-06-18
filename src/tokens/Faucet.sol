// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title  Faucet
/// @notice Rate-limited ERC20 faucet for testnets. Each address can claim `dripAmount`
///         once per `cooldown`.
contract Faucet is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public dripAmount;
    uint256 public cooldown;
    mapping(address => uint256) public lastClaim;

    event Claimed(address indexed to, uint256 amount);
    event Configured(uint256 dripAmount, uint256 cooldown);

    error CooldownActive(uint256 readyAt);

    constructor(address token_, uint256 dripAmount_, uint256 cooldown_, address owner_)
        Ownable(owner_)
    {
        token = IERC20(token_);
        dripAmount = dripAmount_;
        cooldown = cooldown_;
    }

    /// @notice Claim `dripAmount` tokens. Reverts if still in cooldown.
    function claim() external {
        uint256 ready = lastClaim[msg.sender] + cooldown;
        if (block.timestamp < ready) revert CooldownActive(ready);
        lastClaim[msg.sender] = block.timestamp;
        token.safeTransfer(msg.sender, dripAmount);
        emit Claimed(msg.sender, dripAmount);
    }

    function setConfig(uint256 dripAmount_, uint256 cooldown_) external onlyOwner {
        dripAmount = dripAmount_;
        cooldown = cooldown_;
        emit Configured(dripAmount_, cooldown_);
    }

    /// @notice Owner reclaims leftover tokens.
    function sweep(address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }
}
