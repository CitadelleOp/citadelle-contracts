// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/OptionsEngine.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Proxy address from previous deployment
        address proxyAddress = 0xe268a55dD2672Ddb6d7727283B27d9BE601c421a;

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the new V2 implementation
        OptionsEngine newEngineImpl = new OptionsEngine();

        // 2. Upgrade the Proxy to point to the new Implementation
        OptionsEngine engineProxy = OptionsEngine(proxyAddress);
        engineProxy.upgradeToAndCall(address(newEngineImpl), "");

        // 3. Set the backend signer
        engineProxy.setBackendSigner(0x1eeA97BDDe474a3D2E215481870ab17CEd4606dF);

        vm.stopBroadcast();

        console.log("--- UPGRADE SUCCESSFUL ---");
        console.log("OptionsEngine Proxy remains: ", proxyAddress);
        console.log("OptionsEngine New Impl:      ", address(newEngineImpl));
        console.log("Backend Signer Set To:       ", 0x1eeA97BDDe474a3D2E215481870ab17CEd4606dF);
        console.log("--------------------------");
    }
}
