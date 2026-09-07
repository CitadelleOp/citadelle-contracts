// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CitadelleVault.sol";
import "../src/OptionsEngine.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract OptionsEngineTest is Test {
    CitadelleVault vault;
    OptionsEngine engine;
    MockToken weth;
    MockToken usdg;

    address admin = address(1);
    address treasury = address(2);
    address writer = address(3);
    address buyer = address(4);

    function setUp() public {
        vm.startPrank(admin);
        
        weth = new MockToken("Mock WETH", "WETH");
        usdg = new MockToken("Mock USDG", "USDG");
        
        CitadelleVault vaultImpl = new CitadelleVault();
        ERC1967Proxy vaultProxy = new ERC1967Proxy(
            address(vaultImpl),
            abi.encodeWithSelector(CitadelleVault.initialize.selector, treasury)
        );
        vault = CitadelleVault(address(vaultProxy));

        // Add supported tokens
        vault.updateSupportedToken(address(weth), true);
        vault.updateSupportedToken(address(usdg), true);

        OptionsEngine engineImpl = new OptionsEngine();
        ERC1967Proxy engineProxy = new ERC1967Proxy(
            address(engineImpl),
            abi.encodeWithSelector(OptionsEngine.initialize.selector, address(vault))
        );
        engine = OptionsEngine(address(engineProxy));

        // Link Engine to Vault
        vault.setEngine(address(engine));

        vm.stopPrank();

        // Setup balances
        weth.mint(writer, 10000e18);
        weth.mint(buyer, 10000e18);
        
        usdg.mint(writer, 10000e6);
        usdg.mint(buyer, 10000e6);
    }

    function testDepositAndWriteOptionWETH() public {
        vm.startPrank(writer);
        weth.approve(address(vault), 1000e18);
        vault.depositCollateral(address(weth), 1000e18);

        // Expect 1000 WETH in vault for writer
        assertEq(vault.collateralBalances(writer, address(weth)), 1000e18);

        // Write an option (expiry in 7 days)
        uint256 expiry = block.timestamp + 7 days;
        engine.writeOption(address(weth), "AAPL", 150e6, expiry, 500e18, 50e18);
        
        assertEq(vault.lockedMargins(writer, address(weth)), 500e18);
        vm.stopPrank();
    }

    function testBuyOptionUSDG() public {
        // Writer writes option with USDG collateral
        vm.startPrank(writer);
        usdg.approve(address(vault), 1000e6);
        vault.depositCollateral(address(usdg), 1000e6);
        
        uint256 expiry = block.timestamp + 7 days;
        engine.writeOption(address(usdg), "MSFT", 300e6, expiry, 500e6, 20e6);
        vm.stopPrank();

        // Buyer buys the option
        vm.startPrank(buyer);
        usdg.approve(address(engine), 20e6); // Premium is 20 USDG
        engine.buyOption(writer, address(usdg), "MSFT", 300e6, expiry, 20e6);
        vm.stopPrank();

        // Verify fees
        // 2.5% of 20 = 0.5 USDG
        assertEq(usdg.balanceOf(treasury), 500000); 
        // Writer gets 19.5 USDG
        // Writer starting balance: 10000 - 1000 (deposited) = 9000
        // Writer proceeds: 19.5 => 9019.5 USDG
        assertEq(usdg.balanceOf(writer), 9019500000);
    }
}
