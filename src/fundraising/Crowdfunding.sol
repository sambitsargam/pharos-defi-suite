// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title  Crowdfunding
/// @notice All-or-nothing native PHRS crowdfunding. Backers pledge before the deadline; if the
///         goal is met the beneficiary claims the funds, otherwise backers reclaim their pledges.
contract Crowdfunding is ReentrancyGuard {
    address public immutable beneficiary;
    uint256 public immutable goal;
    uint64 public immutable deadline;

    uint256 public pledged;
    bool public claimed;
    mapping(address => uint256) public pledges;

    event Pledged(address indexed backer, uint256 amount);
    event Claimed(uint256 amount);
    event Refunded(address indexed backer, uint256 amount);

    constructor(address beneficiary_, uint256 goal_, uint64 deadline_) {
        require(beneficiary_ != address(0) && goal_ > 0 && deadline_ > block.timestamp, "bad params");
        beneficiary = beneficiary_;
        goal = goal_;
        deadline = deadline_;
    }

    function pledge() external payable nonReentrant {
        require(block.timestamp < deadline, "ended");
        require(msg.value > 0, "zero");
        pledges[msg.sender] += msg.value;
        pledged += msg.value;
        emit Pledged(msg.sender, msg.value);
    }

    /// @notice Beneficiary claims funds if the goal was met after the deadline.
    function claim() external nonReentrant {
        require(block.timestamp >= deadline, "not ended");
        require(pledged >= goal, "goal not met");
        require(!claimed, "claimed");
        claimed = true;
        (bool ok,) = payable(beneficiary).call{value: address(this).balance}("");
        require(ok, "claim failed");
        emit Claimed(pledged);
    }

    /// @notice Backers reclaim pledges if the goal was not met after the deadline.
    function refund() external nonReentrant {
        require(block.timestamp >= deadline, "not ended");
        require(pledged < goal, "goal met");
        uint256 amount = pledges[msg.sender];
        require(amount > 0, "nothing to refund");
        pledges[msg.sender] = 0;
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "refund failed");
        emit Refunded(msg.sender, amount);
    }
}
