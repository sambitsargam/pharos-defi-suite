// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title  DefiTimelock
/// @notice TimelockController that owns protocol contracts and executes governance proposals
///         after a mandatory delay. Set the Governor as proposer and address(0) as executor
///         (open execution) for a standard DAO setup.
contract DefiTimelock is TimelockController {
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        TimelockController(minDelay, proposers, executors, admin)
    {}
}
