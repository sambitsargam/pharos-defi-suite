// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20Factory} from "../src/tokens/ERC20Factory.sol";
import {WrappedNative} from "../src/tokens/WrappedNative.sol";
import {DexFactory} from "../src/dex/DexFactory.sol";
import {DexRouter} from "../src/dex/DexRouter.sol";
import {SimpleOracle} from "../src/oracle/SimpleOracle.sol";

/// @notice Deploys the foundational Pharos DeFi Suite stack (token factory, WPHRS, DEX, oracle).
/// @dev    forge script script/DeploySuite.s.sol:DeploySuite --rpc-url atlantic --broadcast --private-key $PRIVATE_KEY
contract DeploySuite is Script {
    function run() external {
        address owner = msg.sender;
        vm.startBroadcast();

        ERC20Factory tokenFactory = new ERC20Factory();
        WrappedNative wphrs = new WrappedNative();
        DexFactory dexFactory = new DexFactory(owner);
        DexRouter router = new DexRouter(address(dexFactory), address(wphrs));
        SimpleOracle oracle = new SimpleOracle(owner);

        vm.stopBroadcast();

        console2.log("ERC20Factory: ", address(tokenFactory));
        console2.log("WrappedNative:", address(wphrs));
        console2.log("DexFactory:   ", address(dexFactory));
        console2.log("DexRouter:    ", address(router));
        console2.log("SimpleOracle: ", address(oracle));
    }
}
