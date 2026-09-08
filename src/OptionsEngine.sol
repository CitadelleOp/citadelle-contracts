// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Interfaces
interface ICitadelleVault {
    function lockMargin(address user, address token, uint256 amount) external;
    function unlockMargin(address user, address token, uint256 amount) external;
    function treasury() external view returns (address);
    function supportedTokens(address token) external view returns (bool);
}

/**
 * @title OptionsEngine
 * @dev Core engine for Citadelle Options (Multi-Collateral).
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

    // --- V2 Storage ---
    address public backendSigner;
    mapping(string => bool) public isPositionClosed;

    // --- Events ---
    event OptionWritten(address indexed writer, string marketSymbol, uint256 strikePrice, uint256 expiry, address indexed collateralToken, uint256 premium);
    event OptionBought(address indexed buyer, string marketSymbol, uint256 strikePrice, uint256 expiry, address indexed collateralToken, uint256 premium);
    event OptionClosed(address indexed user, string positionId, address indexed collateralToken, uint256 marginUnlocked);
    event BackendSignerUpdated(address oldSigner, address newSigner);

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
    function writeOption(address collateralToken, string memory marketSymbol, uint256 strikePrice, uint256 expiry, uint256 marginRequired, uint256 premiumWanted) external whenNotPaused nonReentrant {
        require(vault.supportedTokens(collateralToken), "Token not supported");
        require(expiry > block.timestamp, "Expiry must be in the future");

        // Lock margin in Vault (Vault will revert if user has insufficient unlocked collateral)
        vault.lockMargin(msg.sender, collateralToken, marginRequired);
        
        emit OptionWritten(msg.sender, marketSymbol, strikePrice, expiry, collateralToken, premiumWanted);
    }

    /**
     * @dev Buy an option. Pays premium to writer, deducts 2.5% fee.
     */
    function buyOption(address writer, address collateralToken, string memory marketSymbol, uint256 strikePrice, uint256 expiry, uint256 premium) external whenNotPaused nonReentrant {
        require(vault.supportedTokens(collateralToken), "Token not supported");
        require(expiry > block.timestamp, "Cannot buy expired option");

        // Calculate fee
        uint256 fee = (premium * FEE_BPS) / BPS_DENOMINATOR;
        uint256 writerProceeds = premium - fee;

        address treasury = vault.treasury();

        // Buyer pays the premium directly to the contract
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), premium);

        // Send fee to Treasury
        if (fee > 0) {
            IERC20(collateralToken).safeTransfer(treasury, fee);
        }
        
        // Send proceeds to Writer
        if (writerProceeds > 0) {
            IERC20(collateralToken).safeTransfer(writer, writerProceeds);
        }
        
        emit OptionBought(msg.sender, marketSymbol, strikePrice, expiry, collateralToken, premium);
    }

    function setBackendSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Invalid signer address");
        emit BackendSignerUpdated(backendSigner, _signer);
        backendSigner = _signer;
    }

    /**
     * @dev Close a position (reclaim margin) securely via backend signature.
     */
    function closeOption(
        string memory positionId,
        address collateralToken, 
        uint256 marginToUnlock, 
        bytes memory signature
    ) external whenNotPaused nonReentrant {
        require(!isPositionClosed[positionId], "Position already closed");
        require(backendSigner != address(0), "Backend signer not set");
        
        // Verify ECDSA Signature
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, positionId, collateralToken, marginToUnlock));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, signature);
        require(signer == backendSigner, "Invalid backend signature");

        isPositionClosed[positionId] = true;
        vault.unlockMargin(msg.sender, collateralToken, marginToUnlock);
        
        emit OptionClosed(msg.sender, positionId, collateralToken, marginToUnlock);
    }
}
