// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title  MasterChef
/// @notice Multi-pool yield farm (SushiSwap-style). The owner adds LP/token pools with
///         allocation points; `rewardToken` is distributed per block, pro-rata by pool
///         weight and stake share. Rewards are pre-funded (transfer rewardToken to this
///         contract); payouts are capped by the available balance.
contract MasterChef is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare; // scaled by 1e12
    }

    IERC20 public immutable rewardToken;
    uint256 public rewardPerBlock;
    uint256 public totalAllocPoint;

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event PoolAdded(uint256 indexed pid, address lpToken, uint256 allocPoint);

    constructor(address rewardToken_, uint256 rewardPerBlock_, address owner_) Ownable(owner_) {
        rewardToken = IERC20(rewardToken_);
        rewardPerBlock = rewardPerBlock_;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(uint256 allocPoint, address lpToken, bool withUpdate) external onlyOwner {
        if (withUpdate) massUpdatePools();
        totalAllocPoint += allocPoint;
        poolInfo.push(
            PoolInfo({
                lpToken: IERC20(lpToken),
                allocPoint: allocPoint,
                lastRewardBlock: block.number,
                accRewardPerShare: 0
            })
        );
        emit PoolAdded(poolInfo.length - 1, lpToken, allocPoint);
    }

    function set(uint256 pid, uint256 allocPoint, bool withUpdate) external onlyOwner {
        if (withUpdate) massUpdatePools();
        totalAllocPoint = totalAllocPoint - poolInfo[pid].allocPoint + allocPoint;
        poolInfo[pid].allocPoint = allocPoint;
    }

    function setRewardPerBlock(uint256 rewardPerBlock_) external onlyOwner {
        massUpdatePools();
        rewardPerBlock = rewardPerBlock_;
    }

    function pendingReward(uint256 pid, address user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage u = userInfo[pid][user];
        uint256 acc = pool.accRewardPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0 && totalAllocPoint != 0) {
            uint256 blocks = block.number - pool.lastRewardBlock;
            uint256 reward = (blocks * rewardPerBlock * pool.allocPoint) / totalAllocPoint;
            acc += (reward * 1e12) / lpSupply;
        }
        return (u.amount * acc) / 1e12 - u.rewardDebt;
    }

    function massUpdatePools() public {
        uint256 len = poolInfo.length;
        for (uint256 pid; pid < len; pid++) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 pid) public {
        PoolInfo storage pool = poolInfo[pid];
        if (block.number <= pool.lastRewardBlock) return;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || totalAllocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 blocks = block.number - pool.lastRewardBlock;
        uint256 reward = (blocks * rewardPerBlock * pool.allocPoint) / totalAllocPoint;
        pool.accRewardPerShare += (reward * 1e12) / lpSupply;
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 pid, uint256 amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage u = userInfo[pid][msg.sender];
        updatePool(pid);
        if (u.amount > 0) {
            uint256 pending = (u.amount * pool.accRewardPerShare) / 1e12 - u.rewardDebt;
            if (pending > 0) _safeRewardTransfer(msg.sender, pending);
        }
        if (amount > 0) {
            pool.lpToken.safeTransferFrom(msg.sender, address(this), amount);
            u.amount += amount;
        }
        u.rewardDebt = (u.amount * pool.accRewardPerShare) / 1e12;
        emit Deposit(msg.sender, pid, amount);
    }

    function withdraw(uint256 pid, uint256 amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage u = userInfo[pid][msg.sender];
        require(u.amount >= amount, "withdraw: insufficient");
        updatePool(pid);
        uint256 pending = (u.amount * pool.accRewardPerShare) / 1e12 - u.rewardDebt;
        if (pending > 0) _safeRewardTransfer(msg.sender, pending);
        if (amount > 0) {
            u.amount -= amount;
            pool.lpToken.safeTransfer(msg.sender, amount);
        }
        u.rewardDebt = (u.amount * pool.accRewardPerShare) / 1e12;
        emit Withdraw(msg.sender, pid, amount);
    }

    function emergencyWithdraw(uint256 pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage u = userInfo[pid][msg.sender];
        uint256 amount = u.amount;
        u.amount = 0;
        u.rewardDebt = 0;
        pool.lpToken.safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, pid, amount);
    }

    function _safeRewardTransfer(address to, uint256 amount) internal {
        uint256 bal = rewardToken.balanceOf(address(this));
        rewardToken.safeTransfer(to, amount > bal ? bal : amount);
    }
}
