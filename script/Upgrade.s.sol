// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/OptionsEngine.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Proxy address from previous deployment
        address proxyAddress = 0xc86Da99C653D55F49a1EC86214a612ac2bAAfbcf;

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the new V2 implementation
        OptionsEngine newEngineImpl = new OptionsEngine();

        // 2. Upgrade the Proxy to point to the new Implementation
        OptionsEngine engineProxy = OptionsEngine(proxyAddress);
        engineProxy.upgradeToAndCall(address(newEngineImpl), "");

        vm.stopBroadcast();

        console.log("--- UPGRADE SUCCESSFUL ---");
        console.log("OptionsEngine Proxy remains: ", proxyAddress);
        console.log("OptionsEngine New Impl:      ", address(newEngineImpl));
        console.log("--------------------------");
    }
}
