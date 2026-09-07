// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CitadelleVault.sol";
import "../src/OptionsEngine.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract OptionsEngineTest is Test {
    CitadelleVault vault;
    OptionsEngine engine;
    MockUSDC usdc;

    address admin = address(1);
    address treasury = address(2);
    address writer = address(3);
    address buyer = address(4);

    function setUp() public {
        vm.startPrank(admin);
        
        usdc = new MockUSDC();
        
        CitadelleVault vaultImpl = new CitadelleVault();
        ERC1967Proxy vaultProxy = new ERC1967Proxy(
            address(vaultImpl),
            abi.encodeWithSelector(CitadelleVault.initialize.selector, address(usdc), treasury)
        );
        vault = CitadelleVault(address(vaultProxy));

        OptionsEngine engineImpl = new OptionsEngine();
        ERC1967Proxy engineProxy = new ERC1967Proxy(
            address(engineImpl),
            abi.encodeWithSelector(OptionsEngine.initialize.selector, address(vault))
        );
        engine = OptionsEngine(address(engineProxy));

        vm.stopPrank();

        // Setup balances
        usdc.mint(writer, 10000e6); // 10k USDC
        usdc.mint(buyer, 10000e6);
    }

    function testDepositAndWriteOption() public {
        vm.startPrank(writer);
        usdc.approve(address(vault), 1000e6);
        vault.depositCollateral(1000e6);

        // Expect 1000 USDC in vault for writer
        assertEq(vault.collateralBalances(writer), 1000e6);

        // Write an option (requires 500 margin, wants 50 premium)
        engine.writeOption("AAPL", 150e6, 500e6, 50e6);
        
        assertEq(vault.lockedMargins(writer), 500e6);
        vm.stopPrank();
    }

    function testBuyOption() public {
        // First writer writes the option
        vm.startPrank(writer);
        usdc.approve(address(vault), 1000e6);
        vault.depositCollateral(1000e6);
        engine.writeOption("AAPL", 150e6, 500e6, 50e6);
        vm.stopPrank();

        // Now buyer buys it for 50 USDC premium
        vm.startPrank(buyer);
        usdc.approve(address(engine), 50e6);
        
        engine.buyOption(writer, "AAPL", 150e6, 50e6);
        vm.stopPrank();

        // Fee is 2.5% of 50 = 1.25 USDC
        assertEq(usdc.balanceOf(treasury), 1250000); // 1.25 * 1e6
        
        // Writer gets 48.75 USDC
        assertEq(usdc.balanceOf(writer), 10000e6 - 1000e6 + 48750000);
    }
}
