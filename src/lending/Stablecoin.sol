// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title  Stablecoin
/// @notice A USD-pegged ERC20 minted/burned only by an authorized minter (the CDPEngine).
contract Stablecoin is ERC20, Ownable {
    address public minter;

    event MinterUpdated(address indexed minter);

    constructor(string memory name_, string memory symbol_, address owner_)
        ERC20(name_, symbol_)
        Ownable(owner_)
    {}

    modifier onlyMinter() {
        require(msg.sender == minter, "not minter");
        _;
    }

    function setMinter(address minter_) external onlyOwner {
        minter = minter_;
        emit MinterUpdated(minter_);
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }
}
