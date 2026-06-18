// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title  LiquidityLocker
/// @notice Time-locks ERC20 tokens (typically LP tokens) to prove liquidity can't be pulled.
///         The lock owner can withdraw only after the unlock time, and may extend it.
contract LiquidityLocker is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Lock {
        address token;
        address owner;
        uint256 amount;
        uint64 unlockTime;
        bool withdrawn;
    }

    mapping(uint256 => Lock) public locks;
    uint256 public nextLockId;

    event Locked(uint256 indexed id, address indexed owner, address token, uint256 amount, uint64 unlockTime);
    event Withdrawn(uint256 indexed id, uint256 amount);
    event Extended(uint256 indexed id, uint64 newUnlockTime);

    function lock(address token, uint256 amount, uint64 unlockTime)
        external
        nonReentrant
        returns (uint256 id)
    {
        require(amount > 0, "zero");
        require(unlockTime > block.timestamp, "unlock in past");
        id = nextLockId++;
        locks[id] = Lock({
            token: token,
            owner: msg.sender,
            amount: amount,
            unlockTime: unlockTime,
            withdrawn: false
        });
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Locked(id, msg.sender, token, amount, unlockTime);
    }

    function withdraw(uint256 id) external nonReentrant {
        Lock storage l = locks[id];
        require(msg.sender == l.owner, "not owner");
        require(!l.withdrawn, "withdrawn");
        require(block.timestamp >= l.unlockTime, "still locked");
        l.withdrawn = true;
        IERC20(l.token).safeTransfer(l.owner, l.amount);
        emit Withdrawn(id, l.amount);
    }

    function extend(uint256 id, uint64 newUnlockTime) external {
        Lock storage l = locks[id];
        require(msg.sender == l.owner, "not owner");
        require(!l.withdrawn, "withdrawn");
        require(newUnlockTime > l.unlockTime, "must extend");
        l.unlockTime = newUnlockTime;
        emit Extended(id, newUnlockTime);
    }
}
