// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title  RevenueSplitter
/// @notice Splits received native PHRS and ERC20 tokens among payees by fixed shares.
///         Pull-based: each payee releases their accrued portion on demand.
contract RevenueSplitter {
    using SafeERC20 for IERC20;

    address[] public payees;
    mapping(address => uint256) public shares;
    uint256 public totalShares;

    uint256 public totalReleasedNative;
    mapping(address => uint256) public releasedNative;
    mapping(address => uint256) public totalReleasedToken; // token => total
    mapping(address => mapping(address => uint256)) public releasedToken; // token => payee => amount

    event PayeeAdded(address account, uint256 shares);
    event NativeReleased(address indexed to, uint256 amount);
    event TokenReleased(address indexed token, address indexed to, uint256 amount);

    constructor(address[] memory payees_, uint256[] memory shares_) {
        require(payees_.length == shares_.length && payees_.length > 0, "bad input");
        for (uint256 i; i < payees_.length; i++) {
            require(payees_[i] != address(0) && shares_[i] > 0, "bad payee");
            require(shares[payees_[i]] == 0, "duplicate");
            payees.push(payees_[i]);
            shares[payees_[i]] = shares_[i];
            totalShares += shares_[i];
            emit PayeeAdded(payees_[i], shares_[i]);
        }
    }

    receive() external payable {}

    function payeeCount() external view returns (uint256) {
        return payees.length;
    }

    function releasableNative(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleasedNative;
        return (totalReceived * shares[account]) / totalShares - releasedNative[account];
    }

    function releasableToken(address token, address account) public view returns (uint256) {
        uint256 totalReceived = IERC20(token).balanceOf(address(this)) + totalReleasedToken[token];
        return (totalReceived * shares[account]) / totalShares - releasedToken[token][account];
    }

    function releaseNative(address payable account) external {
        require(shares[account] > 0, "no shares");
        uint256 payment = releasableNative(account);
        require(payment > 0, "nothing due");
        releasedNative[account] += payment;
        totalReleasedNative += payment;
        (bool ok,) = account.call{value: payment}("");
        require(ok, "native transfer failed");
        emit NativeReleased(account, payment);
    }

    function releaseToken(address token, address account) external {
        require(shares[account] > 0, "no shares");
        uint256 payment = releasableToken(token, account);
        require(payment > 0, "nothing due");
        releasedToken[token][account] += payment;
        totalReleasedToken[token] += payment;
        IERC20(token).safeTransfer(account, payment);
        emit TokenReleased(token, account, payment);
    }
}
