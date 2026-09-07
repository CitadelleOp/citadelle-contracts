// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

/**
 * @title OracleRouter
 * @dev Production Oracle Router integrating with Pyth Network.
 * Fetches real-time, real-world data directly from Pyth.
 */
contract OracleRouter {
    
    IPyth public pyth;

    /**
     * @param pythContract The actual address of the Pyth Network contract on Robinhood Chain/Testnet
     */
    constructor(address pythContract) {
        require(pythContract != address(0), "Invalid Pyth address");
        pyth = IPyth(pythContract);
    }

    /**
     * @dev Fetches the latest price from Pyth Network.
     * Note: getPriceUnsafe is used when off-chain systems are ensuring freshness,
     * or you can use getPrice() if you intend to pass updateData via payable functions.
     * @param priceFeedId The Pyth price feed ID (e.g. AAPL/USD feed ID)
     */
    function getLatestPrice(bytes32 priceFeedId) external view returns (int64 price, uint64 conf, int32 expo, uint256 publishTime) {
        PythStructs.Price memory pythPrice = pyth.getPriceUnsafe(priceFeedId);
        return (pythPrice.price, pythPrice.conf, pythPrice.expo, pythPrice.publishTime);
    }
}
