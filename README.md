# Citadelle Options - Smart Contracts

Welcome to the **Citadelle Options** EVM Smart Contracts repository. This project is built using [Foundry](https://book.getfoundry.sh/) and contains the core on-chain logic for the Citadelle derivatives platform on the **Robinhood Chain**.

## 🏗 Architecture

- **`OptionsEngine.sol`**: The core protocol that handles the minting (writing), buying, and exercising of European-style options.
- **`CitadelleVault.sol`**: Manages user collateral (USDC/WETH), margin locking, and liquidation mechanisms.
- **`OracleRouter.sol`**: Interfaces with external oracles (e.g. Pyth Network) to fetch real-time asset prices for strike settlements.
- **`PerpEngine.sol`**: (Upcoming) Engine for perpetual futures trading.

## 🚀 Quickstart

This project requires **Foundry** (Forge, Cast, Anvil). 

### 1. Build
Compile the smart contracts:
```bash
forge build
```

### 2. Test
Run the test suite:
```bash
forge test
```

### 3. Deploy
Deploy to the Robinhood Testnet (ensure you have set up your `.env` with `PRIVATE_KEY`):
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url robinhood_testnet --broadcast
```

## 📜 Events 
The API Indexer (`citadelle-api`) relies on the following standard EVM events emitted by `OptionsEngine`:
- `OptionWritten(address indexed writer, string marketSymbol, uint256 strikePrice, uint256 premium)`
- `OptionBought(address indexed buyer, string marketSymbol, uint256 strikePrice, uint256 premium)`

## 🛡 License
MIT License
