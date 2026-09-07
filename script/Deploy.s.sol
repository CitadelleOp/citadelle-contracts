// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/CitadelleVault.sol";
import "../src/OptionsEngine.sol";
import "../src/OracleRouter.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Protocol configurations
        address treasuryAddress = vm.envAddress("TREASURY_ADDRESS");
        address pythAddress = vm.envAddress("REAL_PYTH_ADDRESS");
        
        // Supported Collaterals
        address wethAddress = vm.envAddress("WETH_ADDRESS");
        address usdgAddress = vm.envAddress("USDG_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // 0. Enforce REAL Addresses (No Mocks Allowed)
        require(wethAddress != address(0), "Deployment failed: WETH_ADDRESS in .env is missing/empty");
        require(usdgAddress != address(0), "Deployment failed: USDG_ADDRESS in .env is missing/empty");
        require(pythAddress != address(0), "Deployment failed: REAL_PYTH_ADDRESS in .env is missing/empty");
        require(treasuryAddress != address(0), "Deployment failed: TREASURY_ADDRESS in .env is missing/empty");

        // 1. Deploy Vault
        CitadelleVault vaultImpl = new CitadelleVault();
        ERC1967Proxy vaultProxy = new ERC1967Proxy(
            address(vaultImpl),
            abi.encodeWithSelector(CitadelleVault.initialize.selector, treasuryAddress)
        );
        CitadelleVault vault = CitadelleVault(address(vaultProxy));

        // 1a. Whitelist WETH and USDG
        console.log("Whitelisting WETH and USDG...");
        vault.updateSupportedToken(wethAddress, true);
        vault.updateSupportedToken(usdgAddress, true);

        // 2. Deploy Options Engine
        OptionsEngine engineImpl = new OptionsEngine();
        ERC1967Proxy engineProxy = new ERC1967Proxy(
            address(engineImpl),
            abi.encodeWithSelector(OptionsEngine.initialize.selector, address(vault))
        );
        OptionsEngine engine = OptionsEngine(address(engineProxy));

        // 2a. Link Engine to Vault (Access Control)
        console.log("Linking Engine to Vault...");
        vault.setEngine(address(engine));

        // 3. Deploy Oracle Router (Pyth Integration)
        OracleRouter oracle = new OracleRouter(pythAddress);

        // 4. (Optional) Set Oracle in Engine if Engine needs it
        // engine.setOracle(address(oracle)); // Assume we add this later

        vm.stopBroadcast();

        // Print final addresses for Indexer/Frontend
        console.log("--- Deployment Successful ---");
        console.log("CitadelleVault Proxy: ", address(vault));
        console.log("CitadelleVault Impl:  ", address(vaultImpl));
        console.log("OptionsEngine Proxy:  ", address(engine));
        console.log("OptionsEngine Impl:   ", address(engineImpl));
        console.log("OracleRouter:         ", address(oracle));
        console.log("Treasury Address:     ", treasuryAddress);
        console.log("-----------------------------");
    }
}
