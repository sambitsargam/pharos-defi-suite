// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title  StandardERC20
/// @notice Feature-rich ERC20: owner-mintable, burnable, EIP-2612 permit, and an
///         optional hard supply cap. The Swiss-army-knife token for the Pharos DeFi Suite.
contract StandardERC20 is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    /// @notice Maximum total supply. `0` means uncapped.
    uint256 public immutable cap;

    error CapExceeded(uint256 attempted, uint256 cap);

    /// @param name_          Token name.
    /// @param symbol_        Token symbol.
    /// @param initialSupply  Amount minted to `owner_` at deploy (18 decimals).
    /// @param cap_           Hard supply cap (0 = uncapped). Must be >= initialSupply if set.
    /// @param owner_         Owner/minter address.
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        uint256 cap_,
        address owner_
    ) ERC20(name_, symbol_) ERC20Permit(name_) Ownable(owner_) {
        cap = cap_;
        if (cap_ != 0 && initialSupply > cap_) revert CapExceeded(initialSupply, cap_);
        if (initialSupply > 0) _mint(owner_, initialSupply);
    }

    /// @notice Owner mints new tokens (respects the cap if set).
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @dev Enforce the cap on mints.
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        if (cap != 0 && from == address(0) && totalSupply() > cap) {
            revert CapExceeded(totalSupply(), cap);
        }
    }
}
