// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {StandardERC20} from "./StandardERC20.sol";

/// @title  ERC20Factory
/// @notice One-click ERC20 deployer. Tracks every token created and who created it.
contract ERC20Factory {
    address[] public allTokens;
    mapping(address creator => address[] tokens) public tokensOf;

    event TokenCreated(
        address indexed token,
        address indexed creator,
        string name,
        string symbol,
        uint256 initialSupply,
        uint256 cap
    );

    /// @notice Deploy a new StandardERC20. The caller becomes the token owner/minter.
    function createToken(
        string calldata name_,
        string calldata symbol_,
        uint256 initialSupply,
        uint256 cap_
    ) external returns (address token) {
        StandardERC20 t = new StandardERC20(name_, symbol_, initialSupply, cap_, msg.sender);
        token = address(t);
        allTokens.push(token);
        tokensOf[msg.sender].push(token);
        emit TokenCreated(token, msg.sender, name_, symbol_, initialSupply, cap_);
    }

    function allTokensLength() external view returns (uint256) {
        return allTokens.length;
    }

    function tokensOfLength(address creator) external view returns (uint256) {
        return tokensOf[creator].length;
    }
}
