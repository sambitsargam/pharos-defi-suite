// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPriceOracle} from "../oracle/IPriceOracle.sol";

/// @title  LendingPool
/// @notice Compound-style multi-asset money market. Supply assets to earn interest, post
///         collateral, and borrow other listed assets up to your collateral factor.
///         Under-collateralized positions can be liquidated for a bonus.
/// @dev    Reference implementation. Assumes all listed tokens have 18 decimals and oracle
///         prices are USD scaled to 1e18. Indexes are 1e18-scaled.
contract LendingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private constant WAD = 1e18;
    uint256 private constant BPS = 10_000;

    struct Reserve {
        bool listed;
        uint256 borrowIndex; // 1e18, grows with interest
        uint256 supplyIndex; // 1e18, grows as interest is paid to suppliers
        uint256 totalScaledBorrow;
        uint256 totalScaledSupply;
        uint256 ratePerSecond; // borrow interest, 1e18 per second
        uint256 collateralFactorBps; // borrowing power of this asset as collateral
        uint40 lastAccrual;
    }

    address[] public reserveList;
    mapping(address => Reserve) public reserves;
    mapping(address => mapping(address => uint256)) public scaledSupply; // user => token => scaled
    mapping(address => mapping(address => uint256)) public scaledBorrow; // user => token => scaled

    uint256 public liquidationBonusBps = 10_800; // 8% bonus to liquidators
    uint256 public closeFactorBps = 5_000; // max 50% of a borrow repaid per liquidation
    IPriceOracle public oracle;

    event ReserveListed(address indexed token, uint256 ratePerSecond, uint256 collateralFactorBps);
    event Supplied(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event Borrowed(address indexed user, address indexed token, uint256 amount);
    event Repaid(address indexed user, address indexed token, uint256 amount);
    event Liquidated(
        address indexed liquidator,
        address indexed borrower,
        address repayToken,
        uint256 repayAmount,
        address seizeToken,
        uint256 seizeAmount
    );

    constructor(address oracle_, address owner_) Ownable(owner_) {
        oracle = IPriceOracle(oracle_);
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN
    //////////////////////////////////////////////////////////////*/

    function listReserve(address token, uint256 ratePerSecond, uint256 collateralFactorBps)
        external
        onlyOwner
    {
        require(!reserves[token].listed, "already listed");
        require(collateralFactorBps <= BPS, "cf too high");
        reserves[token] = Reserve({
            listed: true,
            borrowIndex: WAD,
            supplyIndex: WAD,
            totalScaledBorrow: 0,
            totalScaledSupply: 0,
            ratePerSecond: ratePerSecond,
            collateralFactorBps: collateralFactorBps,
            lastAccrual: uint40(block.timestamp)
        });
        reserveList.push(token);
        emit ReserveListed(token, ratePerSecond, collateralFactorBps);
    }

    function setOracle(address oracle_) external onlyOwner {
        oracle = IPriceOracle(oracle_);
    }

    function setRiskParams(uint256 liquidationBonusBps_, uint256 closeFactorBps_)
        external
        onlyOwner
    {
        require(closeFactorBps_ <= BPS && liquidationBonusBps_ >= BPS, "bad params");
        liquidationBonusBps = liquidationBonusBps_;
        closeFactorBps = closeFactorBps_;
    }

    function setReserveParams(address token, uint256 ratePerSecond, uint256 collateralFactorBps)
        external
        onlyOwner
    {
        require(reserves[token].listed, "not listed");
        require(collateralFactorBps <= BPS, "cf too high");
        accrue(token);
        reserves[token].ratePerSecond = ratePerSecond;
        reserves[token].collateralFactorBps = collateralFactorBps;
    }

    /*//////////////////////////////////////////////////////////////
                              ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    function accrue(address token) public {
        Reserve storage r = reserves[token];
        uint256 dt = block.timestamp - r.lastAccrual;
        if (dt == 0) return;
        if (r.totalScaledBorrow != 0 && r.ratePerSecond != 0) {
            uint256 totalBorrowsPrev = (r.totalScaledBorrow * r.borrowIndex) / WAD;
            uint256 factor = r.ratePerSecond * dt; // 1e18
            r.borrowIndex += (r.borrowIndex * factor) / WAD;
            uint256 totalBorrowsNew = (r.totalScaledBorrow * r.borrowIndex) / WAD;
            uint256 interest = totalBorrowsNew - totalBorrowsPrev;
            uint256 totalSupplies = (r.totalScaledSupply * r.supplyIndex) / WAD;
            if (totalSupplies > 0 && interest > 0) {
                r.supplyIndex += (r.supplyIndex * interest) / totalSupplies;
            }
        }
        r.lastAccrual = uint40(block.timestamp);
    }

    function supplyBalance(address user, address token) public view returns (uint256) {
        return (scaledSupply[user][token] * reserves[token].supplyIndex) / WAD;
    }

    function borrowBalance(address user, address token) public view returns (uint256) {
        return (scaledBorrow[user][token] * reserves[token].borrowIndex) / WAD;
    }

    /// @return collateralUSD borrowing power (collateral * factor), debtUSD total debt.
    function accountLiquidity(address user)
        public
        view
        returns (uint256 collateralUSD, uint256 debtUSD)
    {
        uint256 len = reserveList.length;
        for (uint256 i; i < len; i++) {
            address token = reserveList[i];
            uint256 price = oracle.getPrice(token);
            uint256 sBal = supplyBalance(user, token);
            if (sBal > 0) {
                collateralUSD +=
                    (sBal * price / WAD) * reserves[token].collateralFactorBps / BPS;
            }
            uint256 bBal = borrowBalance(user, token);
            if (bBal > 0) {
                debtUSD += bBal * price / WAD;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              USER ACTIONS
    //////////////////////////////////////////////////////////////*/

    function supply(address token, uint256 amount) external nonReentrant {
        require(reserves[token].listed, "not listed");
        require(amount > 0, "zero");
        accrue(token);
        Reserve storage r = reserves[token];
        uint256 scaled = (amount * WAD) / r.supplyIndex;
        scaledSupply[msg.sender][token] += scaled;
        r.totalScaledSupply += scaled;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Supplied(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        accrue(token);
        Reserve storage r = reserves[token];
        uint256 bal = supplyBalance(msg.sender, token);
        require(amount <= bal, "insufficient supply");
        uint256 scaled = (amount * WAD) / r.supplyIndex;
        scaledSupply[msg.sender][token] -= scaled;
        r.totalScaledSupply -= scaled;
        IERC20(token).safeTransfer(msg.sender, amount);
        (uint256 col, uint256 debt) = accountLiquidity(msg.sender);
        require(col >= debt, "would be undercollateralized");
        emit Withdrawn(msg.sender, token, amount);
    }

    function borrow(address token, uint256 amount) external nonReentrant {
        require(reserves[token].listed, "not listed");
        require(amount > 0, "zero");
        accrue(token);
        Reserve storage r = reserves[token];
        uint256 scaled = (amount * WAD) / r.borrowIndex;
        scaledBorrow[msg.sender][token] += scaled;
        r.totalScaledBorrow += scaled;
        (uint256 col, uint256 debt) = accountLiquidity(msg.sender);
        require(col >= debt, "insufficient collateral");
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Borrowed(msg.sender, token, amount);
    }

    function repay(address token, uint256 amount) external nonReentrant {
        accrue(token);
        _repay(msg.sender, msg.sender, token, amount);
    }

    function _repay(address payer, address borrower, address token, uint256 amount)
        internal
        returns (uint256 repaid)
    {
        Reserve storage r = reserves[token];
        uint256 debt = borrowBalance(borrower, token);
        repaid = amount > debt ? debt : amount;
        uint256 scaled = (repaid * WAD) / r.borrowIndex;
        scaledBorrow[borrower][token] -= scaled;
        r.totalScaledBorrow -= scaled;
        IERC20(token).safeTransferFrom(payer, address(this), repaid);
        emit Repaid(borrower, token, repaid);
    }

    /// @notice Liquidate an unhealthy borrower: repay `repayToken` debt, seize `seizeToken`
    ///         collateral plus a bonus.
    function liquidate(address borrower, address repayToken, uint256 repayAmount, address seizeToken)
        external
        nonReentrant
    {
        accrue(repayToken);
        accrue(seizeToken);
        (uint256 col, uint256 debt) = accountLiquidity(borrower);
        require(debt > col, "borrower healthy");

        uint256 maxRepay = (borrowBalance(borrower, repayToken) * closeFactorBps) / BPS;
        if (repayAmount > maxRepay) repayAmount = maxRepay;
        uint256 repaid = _repay(msg.sender, borrower, repayToken, repayAmount);

        // seize = repaidUSD * bonus / seizePrice
        uint256 repaidUSD = repaid * oracle.getPrice(repayToken) / WAD;
        uint256 seizeUSD = repaidUSD * liquidationBonusBps / BPS;
        uint256 seizeAmount = seizeUSD * WAD / oracle.getPrice(seizeToken);

        Reserve storage sr = reserves[seizeToken];
        uint256 seizeScaled = (seizeAmount * WAD) / sr.supplyIndex;
        require(scaledSupply[borrower][seizeToken] >= seizeScaled, "seize exceeds collateral");
        scaledSupply[borrower][seizeToken] -= seizeScaled;
        scaledSupply[msg.sender][seizeToken] += seizeScaled;

        emit Liquidated(msg.sender, borrower, repayToken, repaid, seizeToken, seizeAmount);
    }

    function reserveListLength() external view returns (uint256) {
        return reserveList.length;
    }
}
