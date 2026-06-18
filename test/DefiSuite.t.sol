// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StandardERC20} from "../src/tokens/StandardERC20.sol";
import {WrappedNative} from "../src/tokens/WrappedNative.sol";
import {DexFactory} from "../src/dex/DexFactory.sol";
import {DexRouter} from "../src/dex/DexRouter.sol";
import {StakingRewards} from "../src/yield/StakingRewards.sol";
import {SimpleOracle} from "../src/oracle/SimpleOracle.sol";
import {LendingPool} from "../src/lending/LendingPool.sol";
import {Stablecoin} from "../src/lending/Stablecoin.sol";
import {CDPEngine} from "../src/lending/CDPEngine.sol";

contract DefiSuiteTest is Test {
    address self = address(this);
    address alice = makeAddr("alice");

    function _token(string memory s, uint256 supply) internal returns (StandardERC20 t) {
        t = new StandardERC20(s, s, supply, 0, self);
    }

    /*//////////////////////////////////////////////////////////////
                                  DEX
    //////////////////////////////////////////////////////////////*/

    function test_DexAddLiquidityAndSwap() public {
        StandardERC20 a = _token("AAA", 1_000_000 ether);
        StandardERC20 b = _token("BBB", 1_000_000 ether);
        DexFactory factory = new DexFactory(self);
        WrappedNative wnative = new WrappedNative();
        DexRouter router = new DexRouter(address(factory), address(wnative));

        a.approve(address(router), type(uint256).max);
        b.approve(address(router), type(uint256).max);

        (,, uint256 liq) = router.addLiquidity(
            address(a), address(b), 1000 ether, 1000 ether, 0, 0, self, block.timestamp
        );
        assertGt(liq, 0, "no LP minted");

        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        uint256 beforeB = b.balanceOf(self);
        uint256[] memory amounts =
            router.swapExactTokensForTokens(100 ether, 1, path, self, block.timestamp);
        assertEq(b.balanceOf(self) - beforeB, amounts[1], "swap output mismatch");
        assertGt(amounts[1], 90 ether, "unexpected slippage"); // ~90.6 out for 100 in
    }

    /*//////////////////////////////////////////////////////////////
                                STAKING
    //////////////////////////////////////////////////////////////*/

    function test_StakingRewardsAccrue() public {
        StandardERC20 stakeTok = _token("STK", 1_000_000 ether);
        StandardERC20 rewardTok = _token("RWD", 1_000_000 ether);
        StakingRewards staking = new StakingRewards(address(stakeTok), address(rewardTok), self);

        rewardTok.transfer(address(staking), 7000 ether);
        staking.notifyRewardAmount(7000 ether); // over 7 days

        stakeTok.approve(address(staking), type(uint256).max);
        staking.stake(1000 ether);

        vm.warp(block.timestamp + 1 days);
        uint256 earned = staking.earned(self);
        assertApproxEqAbs(earned, 1000 ether, 5 ether, "should earn ~1/7 of 7000 in 1 day");
    }

    /*//////////////////////////////////////////////////////////////
                                LENDING
    //////////////////////////////////////////////////////////////*/

    function test_LendingSupplyBorrow() public {
        StandardERC20 collat = _token("COL", 1_000_000 ether);
        StandardERC20 debt = _token("DBT", 1_000_000 ether);
        SimpleOracle oracle = new SimpleOracle(self);
        oracle.setPrice(address(collat), 1 ether);
        oracle.setPrice(address(debt), 1 ether);

        LendingPool pool = new LendingPool(address(oracle), self);
        pool.listReserve(address(collat), 0, 7500); // 75% CF
        pool.listReserve(address(debt), 0, 0);

        // provide debt liquidity
        debt.transfer(alice, 10_000 ether);
        vm.startPrank(alice);
        debt.approve(address(pool), type(uint256).max);
        pool.supply(address(debt), 10_000 ether);
        vm.stopPrank();

        // supply collateral, borrow debt
        collat.approve(address(pool), type(uint256).max);
        pool.supply(address(collat), 1000 ether); // $1000 collateral
        pool.borrow(address(debt), 700 ether); // within 75% = $750 limit
        // started 1,000,000, sent 10,000 to alice, borrowed 700 => 990,700
        assertEq(debt.balanceOf(self), 990_700 ether);

        (uint256 col, uint256 d) = pool.accountLiquidity(self);
        assertEq(col, 750 ether);
        assertEq(d, 700 ether);

        // borrowing beyond limit reverts
        vm.expectRevert();
        pool.borrow(address(debt), 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                                  CDP
    //////////////////////////////////////////////////////////////*/

    function test_CDPMintAgainstCollateral() public {
        StandardERC20 collat = _token("WETH", 1_000_000 ether);
        SimpleOracle oracle = new SimpleOracle(self);
        oracle.setPrice(address(collat), 2000 ether); // $2000

        Stablecoin usd = new Stablecoin("Pharos USD", "pUSD", self);
        CDPEngine cdp = new CDPEngine(address(collat), address(usd), address(oracle), self);
        usd.setMinter(address(cdp));

        collat.approve(address(cdp), type(uint256).max);
        cdp.deposit(1 ether); // $2000 collateral
        cdp.mint(1000 ether); // 200% ratio, above 150% min
        assertEq(usd.balanceOf(self), 1000 ether);
        assertGe(cdp.collateralRatio(self), 15_000);

        // over-minting reverts (would drop below 150%)
        vm.expectRevert();
        cdp.mint(400 ether); // total 1400 -> ratio 142% < 150%
    }
}
