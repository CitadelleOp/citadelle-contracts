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
        address usdcAddress = vm.envAddress("REAL_USDC_ADDRESS");
        address pythAddress = vm.envAddress("REAL_PYTH_ADDRESS");
        address treasuryAddress = vm.envAddress("TREASURY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Vault
        CitadelleVault vaultImpl = new CitadelleVault();
        ERC1967Proxy vaultProxy = new ERC1967Proxy(
            address(vaultImpl),
            abi.encodeWithSelector(CitadelleVault.initialize.selector, usdcAddress, treasuryAddress)
        );
        CitadelleVault vault = CitadelleVault(address(vaultProxy));
        
        // 2. Deploy Options Engine
        OptionsEngine engineImpl = new OptionsEngine();
        ERC1967Proxy engineProxy = new ERC1967Proxy(
            address(engineImpl),
            abi.encodeWithSelector(OptionsEngine.initialize.selector, address(vault))
        );
        OptionsEngine engine = OptionsEngine(address(engineProxy));

        // 3. Deploy Oracle Router (Real Pyth Data)
        OracleRouter oracle = new OracleRouter(pythAddress);

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("Vault Proxy Deployed at:", address(vault));
        console.log("Engine Proxy Deployed at:", address(engine));
        console.log("Oracle Router Deployed at:", address(oracle));
    }
}
