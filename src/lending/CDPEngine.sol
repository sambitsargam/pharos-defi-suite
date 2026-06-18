// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPriceOracle} from "../oracle/IPriceOracle.sol";
import {Stablecoin} from "./Stablecoin.sol";

/// @title  CDPEngine
/// @notice Collateralized Debt Position engine (MakerDAO-style, single collateral). Deposit
///         collateral, mint a USD stablecoin against it up to a minimum collateral ratio,
///         repay to free collateral. Unsafe positions can be liquidated for a bonus.
/// @dev    Assumes 18-decimal collateral and that the stablecoin is pegged to $1 (1e18).
contract CDPEngine is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private constant WAD = 1e18;
    uint256 private constant BPS = 10_000;

    IERC20 public immutable collateral;
    Stablecoin public immutable stable;
    IPriceOracle public oracle;

    uint256 public minCollateralRatioBps = 15_000; // 150%
    uint256 public liquidationBonusBps = 11_000; // 110% of debt value seized

    mapping(address => uint256) public collateralOf;
    mapping(address => uint256) public debtOf;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Minted(address indexed user, uint256 amount);
    event Burned(address indexed user, uint256 amount);
    event Liquidated(address indexed liquidator, address indexed user, uint256 debtCovered, uint256 collateralSeized);

    constructor(address collateral_, address stable_, address oracle_, address owner_)
        Ownable(owner_)
    {
        collateral = IERC20(collateral_);
        stable = Stablecoin(stable_);
        oracle = IPriceOracle(oracle_);
    }

    function setParams(uint256 minCollateralRatioBps_, uint256 liquidationBonusBps_)
        external
        onlyOwner
    {
        require(minCollateralRatioBps_ >= BPS && liquidationBonusBps_ >= BPS, "bad params");
        minCollateralRatioBps = minCollateralRatioBps_;
        liquidationBonusBps = liquidationBonusBps_;
    }

    function setOracle(address oracle_) external onlyOwner {
        oracle = IPriceOracle(oracle_);
    }

    function collateralValueUSD(address user) public view returns (uint256) {
        return collateralOf[user] * oracle.getPrice(address(collateral)) / WAD;
    }

    /// @return ratio collateralization ratio in BPS (type(uint).max if no debt).
    function collateralRatio(address user) public view returns (uint256 ratio) {
        uint256 debt = debtOf[user];
        if (debt == 0) return type(uint256).max;
        return collateralValueUSD(user) * BPS / debt; // stable = $1
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "zero");
        collateralOf[msg.sender] += amount;
        collateral.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(collateralOf[msg.sender] >= amount, "insufficient");
        collateralOf[msg.sender] -= amount;
        require(collateralRatio(msg.sender) >= minCollateralRatioBps, "unsafe");
        collateral.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function mint(uint256 amount) external nonReentrant {
        require(amount > 0, "zero");
        debtOf[msg.sender] += amount;
        require(collateralRatio(msg.sender) >= minCollateralRatioBps, "unsafe");
        stable.mint(msg.sender, amount);
        emit Minted(msg.sender, amount);
    }

    function burn(uint256 amount) external nonReentrant {
        uint256 debt = debtOf[msg.sender];
        uint256 pay = amount > debt ? debt : amount;
        debtOf[msg.sender] -= pay;
        stable.burn(msg.sender, pay);
        emit Burned(msg.sender, pay);
    }

    /// @notice Liquidate an unsafe vault. Liquidator burns `debtAmount` stablecoin and seizes
    ///         collateral worth `debtAmount * liquidationBonus`.
    function liquidate(address user, uint256 debtAmount) external nonReentrant {
        require(collateralRatio(user) < minCollateralRatioBps, "user safe");
        uint256 debt = debtOf[user];
        uint256 cover = debtAmount > debt ? debt : debtAmount;

        uint256 seizeUSD = cover * liquidationBonusBps / BPS;
        uint256 seize = seizeUSD * WAD / oracle.getPrice(address(collateral));
        if (seize > collateralOf[user]) seize = collateralOf[user];

        debtOf[user] -= cover;
        collateralOf[user] -= seize;
        stable.burn(msg.sender, cover);
        collateral.safeTransfer(msg.sender, seize);
        emit Liquidated(msg.sender, user, cover, seize);
    }
}
