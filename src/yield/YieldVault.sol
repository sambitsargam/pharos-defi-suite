// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title  YieldVault
/// @notice Tokenized yield vault (ERC-4626). Users deposit an underlying asset and receive
///         shares; yield accrues as the vault's asset balance grows (via `harvest` donations
///         or an external strategy), increasing each share's redeemable value.
contract YieldVault is ERC4626 {
    using SafeERC20 for IERC20;

    constructor(IERC20 asset_, string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
        ERC4626(asset_)
    {}

    /// @notice Add yield to the vault (donate assets to all shareholders pro-rata).
    /// @dev    Caller must approve the vault for `amount` of the underlying first.
    function harvest(uint256 amount) external {
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
    }
}
