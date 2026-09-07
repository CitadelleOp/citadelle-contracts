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
 * @dev Manages user collateral (WETH, USDG, etc.) for trading on Citadelle Options.
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

    address public treasury;
    address public engine;

    // token => isSupported
    mapping(address => bool) public supportedTokens;

    // user => token => balance
    mapping(address => mapping(address => uint256)) public collateralBalances;

    // user => token => locked margin (for open positions)
    mapping(address => mapping(address => uint256)) public lockedMargins;

    event TokenSupportUpdated(address indexed token, bool isSupported);
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 amount);
    event MarginLocked(address indexed user, address indexed token, uint256 amount);
    event MarginUnlocked(address indexed user, address indexed token, uint256 amount);
    event FeeCollected(address indexed token, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _treasury) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();

        require(_treasury != address(0), "Invalid Treasury address");
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

    function setEngine(address _engine) external onlyOwner {
        require(_engine != address(0), "Invalid Engine address");
        engine = _engine;
    }

    function updateSupportedToken(address token, bool isSupported) external onlyOwner {
        require(token != address(0), "Invalid token address");
        supportedTokens[token] = isSupported;
        emit TokenSupportUpdated(token, isSupported);
    }

    function depositCollateral(address token, uint256 amount) external whenNotPaused nonReentrant {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Deposit must be > 0");
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        collateralBalances[msg.sender][token] += amount;
        
        emit CollateralDeposited(msg.sender, token, amount);
    }

    function withdrawCollateral(address token, uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "Withdraw must be > 0");
        uint256 availableBalance = collateralBalances[msg.sender][token] - lockedMargins[msg.sender][token];
        require(availableBalance >= amount, "Insufficient available collateral");

        collateralBalances[msg.sender][token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        
        emit CollateralWithdrawn(msg.sender, token, amount);
    }

    // --- Internal/Engine functions ---
    // Restricted to OptionsEngine contract via access control
    
    modifier onlyEngine() {
        require(msg.sender == engine, "CitadelleVault: Caller is not the Engine");
        _;
    }

    function lockMargin(address user, address token, uint256 amount) external whenNotPaused onlyEngine {
        require(collateralBalances[user][token] - lockedMargins[user][token] >= amount, "Insufficient collateral to lock");
        lockedMargins[user][token] += amount;
        emit MarginLocked(user, token, amount);
    }

    function unlockMargin(address user, address token, uint256 amount) external onlyEngine {
        require(lockedMargins[user][token] >= amount, "Unlock amount exceeds locked");
        lockedMargins[user][token] -= amount;
        emit MarginUnlocked(user, token, amount);
    }

    function transferFeeToTreasury(address token, uint256 amount) external onlyEngine {
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient vault balance for fee");
        IERC20(token).safeTransfer(treasury, amount);
        emit FeeCollected(token, amount);
    }
}
