// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interfaces
interface ICitadelleVault {
    function lockMargin(address user, uint256 amount) external;
    function unlockMargin(address user, uint256 amount) external;
    function treasury() external view returns (address);
    function usdc() external view returns (IERC20);
}

/**
 * @title OptionsEngine
 * @dev Core engine for Citadelle Options (European Call/Put).
 */
contract OptionsEngine is 
    Initializable, 
    UUPSUpgradeable, 
    OwnableUpgradeable, 
    PausableUpgradeable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    ICitadelleVault public vault;
    
    // Fee is 2.5% of premium (250 basis points)
    uint256 public constant FEE_BPS = 250;
    uint256 public constant BPS_DENOMINATOR = 10000;

    // --- Events ---
    event OptionWritten(address indexed writer, string marketSymbol, uint256 strikePrice, uint256 premium);
    event OptionBought(address indexed buyer, string marketSymbol, uint256 strikePrice, uint256 premium);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _vault) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();

        require(_vault != address(0), "Invalid Vault address");
        vault = ICitadelleVault(_vault);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // --- Core Logic ---

    /**
     * @dev Write an option. Locks margin in the vault.
     */
    function writeOption(string memory marketSymbol, uint256 strikePrice, uint256 marginRequired, uint256 premiumWanted) external whenNotPaused nonReentrant {
        // Lock margin in Vault (Vault will revert if user has insufficient unlocked collateral)
        vault.lockMargin(msg.sender, marginRequired);
        
        emit OptionWritten(msg.sender, marketSymbol, strikePrice, premiumWanted);
    }

    /**
     * @dev Buy an option. Pays premium to writer, deducts 2.5% fee.
     * Note: Simplified representation. In production, this matches a specific order ID.
     */
    function buyOption(address writer, string memory marketSymbol, uint256 strikePrice, uint256 premium) external whenNotPaused nonReentrant {
        // Calculate fee
        uint256 fee = (premium * FEE_BPS) / BPS_DENOMINATOR;
        uint256 writerProceeds = premium - fee;

        IERC20 usdc = vault.usdc();
        address treasury = vault.treasury();

        // Buyer pays the premium directly to the contract
        usdc.safeTransferFrom(msg.sender, address(this), premium);

        // Send fee to Treasury
        usdc.safeTransfer(treasury, fee);
        
        // Send proceeds to Writer
        usdc.safeTransfer(writer, writerProceeds);
        
        emit OptionBought(msg.sender, marketSymbol, strikePrice, premium);
    }
}
