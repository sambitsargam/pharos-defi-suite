// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

/// @title  FlashLender
/// @notice ERC-3156 flash loan provider for a single token. Anyone can borrow up to the
///         pool's balance within one transaction, paying a fee. LPs deposit the token to
///         provide liquidity (fees accrue to the pool).
contract FlashLender is IERC3156FlashLender, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    IERC20 public immutable token;
    uint256 public feeBps; // e.g. 9 = 0.09%

    event FlashLoaned(address indexed borrower, uint256 amount, uint256 fee);

    constructor(address token_, uint256 feeBps_, address owner_) Ownable(owner_) {
        token = IERC20(token_);
        feeBps = feeBps_;
    }

    function setFeeBps(uint256 feeBps_) external onlyOwner {
        require(feeBps_ <= 1000, "fee too high");
        feeBps = feeBps_;
    }

    /// @notice Provide liquidity to the pool.
    function deposit(uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Owner withdraws pool liquidity (principal + accrued fees).
    function withdraw(address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }

    function maxFlashLoan(address token_) public view returns (uint256) {
        return token_ == address(token) ? token.balanceOf(address(this)) : 0;
    }

    function flashFee(address token_, uint256 amount) public view returns (uint256) {
        require(token_ == address(token), "unsupported token");
        return (amount * feeBps) / 10_000;
    }

    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token_,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant returns (bool) {
        require(token_ == address(token), "unsupported token");
        require(amount <= maxFlashLoan(token_), "amount exceeds liquidity");
        uint256 fee = flashFee(token_, amount);
        uint256 balanceBefore = token.balanceOf(address(this));

        token.safeTransfer(address(receiver), amount);
        require(
            receiver.onFlashLoan(msg.sender, token_, amount, fee, data) == CALLBACK_SUCCESS,
            "callback failed"
        );
        // Pull back principal + fee.
        token.safeTransferFrom(address(receiver), address(this), amount + fee);
        require(token.balanceOf(address(this)) >= balanceBefore + fee, "not repaid");

        emit FlashLoaned(address(receiver), amount, fee);
        return true;
    }
}
