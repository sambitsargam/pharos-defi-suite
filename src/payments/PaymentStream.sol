// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title  PaymentStream
/// @notice Sablier-style continuous payment streams. A payer locks tokens that vest to the
///         recipient linearly per second; the recipient withdraws accrued funds anytime, and
///         either party-defined cancel splits the remainder fairly.
contract PaymentStream is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Stream {
        address token;
        address sender;
        address recipient;
        uint256 deposit;
        uint256 withdrawn;
        uint64 start;
        uint64 stop;
        bool cancelled;
    }

    mapping(uint256 => Stream) public streams;
    uint256 public nextStreamId;

    event StreamCreated(uint256 indexed id, address indexed sender, address indexed recipient, uint256 deposit);
    event Withdraw(uint256 indexed id, uint256 amount);
    event Cancelled(uint256 indexed id, uint256 toRecipient, uint256 toSender);

    /// @notice Create a stream paying `deposit` linearly from `start` to `stop`.
    function createStream(
        address token,
        address recipient,
        uint256 deposit,
        uint64 start,
        uint64 stop
    ) external returns (uint256 id) {
        require(recipient != address(0) && recipient != msg.sender, "bad recipient");
        require(stop > start && start >= block.timestamp, "bad time window");
        require(deposit > 0, "zero deposit");
        id = nextStreamId++;
        streams[id] = Stream({
            token: token,
            sender: msg.sender,
            recipient: recipient,
            deposit: deposit,
            withdrawn: 0,
            start: start,
            stop: stop,
            cancelled: false
        });
        IERC20(token).safeTransferFrom(msg.sender, address(this), deposit);
        emit StreamCreated(id, msg.sender, recipient, deposit);
    }

    /// @notice Amount that has streamed to the recipient so far (gross of withdrawals).
    function streamedAmount(uint256 id) public view returns (uint256) {
        Stream storage s = streams[id];
        if (block.timestamp <= s.start) return 0;
        if (block.timestamp >= s.stop) return s.deposit;
        return (s.deposit * (block.timestamp - s.start)) / (s.stop - s.start);
    }

    function balanceOf(uint256 id) public view returns (uint256) {
        return streamedAmount(id) - streams[id].withdrawn;
    }

    function withdraw(uint256 id, uint256 amount) external nonReentrant {
        Stream storage s = streams[id];
        require(msg.sender == s.recipient, "not recipient");
        uint256 avail = balanceOf(id);
        require(amount <= avail, "exceeds available");
        s.withdrawn += amount;
        IERC20(s.token).safeTransfer(s.recipient, amount);
        emit Withdraw(id, amount);
    }

    /// @notice Cancel the stream. Recipient gets what has streamed; sender gets the rest.
    function cancel(uint256 id) external nonReentrant {
        Stream storage s = streams[id];
        require(msg.sender == s.sender || msg.sender == s.recipient, "not party");
        require(!s.cancelled, "cancelled");
        uint256 toRecipient = balanceOf(id);
        uint256 toSender = s.deposit - s.withdrawn - toRecipient;
        s.cancelled = true;
        s.withdrawn = s.deposit;
        if (toRecipient > 0) IERC20(s.token).safeTransfer(s.recipient, toRecipient);
        if (toSender > 0) IERC20(s.token).safeTransfer(s.sender, toSender);
        emit Cancelled(id, toRecipient, toSender);
    }
}
