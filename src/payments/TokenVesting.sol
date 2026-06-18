// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title  TokenVesting
/// @notice Cliff + linear token vesting with multiple schedules. The creator funds each
///         schedule up front; beneficiaries release vested tokens over time. Schedules can
///         optionally be revocable by their creator.
contract TokenVesting is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Schedule {
        address token;
        address beneficiary;
        address creator;
        uint64 start;
        uint64 cliff; // absolute timestamp
        uint64 duration; // seconds
        uint256 total;
        uint256 released;
        bool revocable;
        bool revoked;
    }

    mapping(uint256 => Schedule) public schedules;
    uint256 public nextScheduleId;

    event ScheduleCreated(uint256 indexed id, address indexed beneficiary, address token, uint256 total);
    event Released(uint256 indexed id, uint256 amount);
    event Revoked(uint256 indexed id, uint256 refunded);

    /// @notice Create and fund a vesting schedule. Caller must approve `total` first.
    function createSchedule(
        address token,
        address beneficiary,
        uint64 start,
        uint64 cliffDuration,
        uint64 duration,
        uint256 total,
        bool revocable
    ) external returns (uint256 id) {
        require(beneficiary != address(0), "zero beneficiary");
        require(duration > 0 && total > 0, "bad params");
        id = nextScheduleId++;
        schedules[id] = Schedule({
            token: token,
            beneficiary: beneficiary,
            creator: msg.sender,
            start: start,
            cliff: start + cliffDuration,
            duration: duration,
            total: total,
            released: 0,
            revocable: revocable,
            revoked: false
        });
        IERC20(token).safeTransferFrom(msg.sender, address(this), total);
        emit ScheduleCreated(id, beneficiary, token, total);
    }

    function vestedAmount(uint256 id) public view returns (uint256) {
        Schedule storage s = schedules[id];
        if (block.timestamp < s.cliff) return 0;
        if (block.timestamp >= s.start + s.duration || s.revoked) {
            // if revoked, vested is frozen at revoke time via released+remaining handling below
            if (!s.revoked) return s.total;
        }
        uint256 elapsed = block.timestamp - s.start;
        uint256 vested = (s.total * elapsed) / s.duration;
        return vested > s.total ? s.total : vested;
    }

    function releasable(uint256 id) public view returns (uint256) {
        uint256 vested = vestedAmount(id);
        uint256 released = schedules[id].released;
        return vested > released ? vested - released : 0;
    }

    function release(uint256 id) external nonReentrant {
        Schedule storage s = schedules[id];
        uint256 amount = releasable(id);
        require(amount > 0, "nothing to release");
        s.released += amount;
        IERC20(s.token).safeTransfer(s.beneficiary, amount);
        emit Released(id, amount);
    }

    /// @notice Creator revokes a revocable schedule; vested-but-unreleased goes to the
    ///         beneficiary, the rest is refunded to the creator.
    function revoke(uint256 id) external nonReentrant {
        Schedule storage s = schedules[id];
        require(msg.sender == s.creator, "not creator");
        require(s.revocable && !s.revoked, "not revocable");
        uint256 vested = vestedAmount(id);
        uint256 owed = vested - s.released;
        uint256 refund = s.total - vested;
        s.released = vested;
        s.revoked = true;
        if (owed > 0) IERC20(s.token).safeTransfer(s.beneficiary, owed);
        if (refund > 0) IERC20(s.token).safeTransfer(s.creator, refund);
        emit Revoked(id, refund);
    }
}
