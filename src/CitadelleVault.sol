// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title CitadelleVault
 * @dev Manages user collateral (USDC) for trading on Citadelle Options.
 * Uses UUPS Upgradeability and Ownable for Access Control.
 */
contract CitadelleVault is 
    Initializable, 
    UUPSUpgradeable, 
    OwnableUpgradeable, 
    PausableUpgradeable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    IERC20 public usdc;
    address public treasury;

    // user => balance
    mapping(address => uint256) public collateralBalances;

    // user => locked margin (for open positions)
    mapping(address => uint256) public lockedMargins;

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event MarginLocked(address indexed user, uint256 amount);
    event MarginUnlocked(address indexed user, uint256 amount);
    event FeeCollected(uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _usdc, address _treasury) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();

        require(_usdc != address(0), "Invalid USDC address");
        require(_treasury != address(0), "Invalid Treasury address");

        usdc = IERC20(_usdc);
        treasury = _treasury;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid Treasury address");
        treasury = _treasury;
    }

    function depositCollateral(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "Deposit must be > 0");
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        collateralBalances[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "Withdraw must be > 0");
        uint256 availableBalance = collateralBalances[msg.sender] - lockedMargins[msg.sender];
        require(availableBalance >= amount, "Insufficient available collateral");

        collateralBalances[msg.sender] -= amount;
        usdc.safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, amount);
    }

    // --- Internal/Engine functions ---
    // In production, these should be restricted to OptionsEngine contract via access control
    
    function lockMargin(address user, uint256 amount) external whenNotPaused {
        // TODO: Add strict access control (onlyEngine)
        require(collateralBalances[user] - lockedMargins[user] >= amount, "Insufficient collateral to lock");
        lockedMargins[user] += amount;
        emit MarginLocked(user, amount);
    }

    function unlockMargin(address user, uint256 amount) external {
        // TODO: Add strict access control (onlyEngine)
        require(lockedMargins[user] >= amount, "Unlock amount exceeds locked");
        lockedMargins[user] -= amount;
        emit MarginUnlocked(user, amount);
    }

    function transferFeeToTreasury(uint256 amount) external {
        // TODO: Add strict access control (onlyEngine)
        require(usdc.balanceOf(address(this)) >= amount, "Insufficient vault balance for fee");
        usdc.safeTransfer(treasury, amount);
        emit FeeCollected(amount);
    }
}
