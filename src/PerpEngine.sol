// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PerpEngine
 * @dev Core engine for Citadelle Perpetual Futures.
 */
contract PerpEngine {
    
    // TODO: Track Entry Price, Mark Price, Position Size, Collateral, Leverage.
    // TODO: Implement Liquidation logic based on Isolated Margin.
    // TODO: Implement Funding Rate calculations.
    
    function openPosition() external payable {
        // Placeholder for opening Long/Short perp position.
    }
    
    function closePosition() external {
        // Placeholder for closing perp position and settling PnL.
    }
}
