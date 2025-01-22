// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.26;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IOkxMultiRound} from "../interfaces/IOkxMultiRound.sol";

/// @custom:security-contact mr.nmh175@gmail.com
contract OkxMultiRound is Initializable, IOkxMultiRound, EIP712Upgradeable, AccessControlUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    bytes32 public constant MINT_AUTH_TYPE_HASH =
        keccak256("MintAuth(address to,uint256 tokenId,uint256 amount,uint256 nonce,uint256 expiry,string stage)");

    address public signer;
    mapping(bytes signature => bool used) public usedSignatures;
    mapping(address => mapping(string => uint256)) public mintRecord; //Address mint record in each stage.
    mapping(string => StageMintInfo) public stageToMint; // Stage to single stage mint information.
    mapping(string => uint256) public stageToTotalSupply; //Minted amount for each stage.
    uint256 public maxSupply;
    uint256 public totalMintedAmount;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address pauser, address minter) public initializer {
        __AccessControl_init();
        __EIP712_init("PunkNFT", "1.0");

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
    }

    function __OkxMultiRound_init(address _signer, uint256 _maxSupply) public initializer {
        signer = _signer;
        maxSupply = _maxSupply;
    }

    function _registerMinting(string calldata stage, bytes calldata signature, MintParams calldata mintparams)
        internal
        returns (uint256 amount)
    {
        amount = mintparams.amount;
        _useSignature(stage, signature, mintparams);
        _validateActive(stage);
        _validateAmount(stage, mintparams.to, amount);
        _increaseMintRecord(stage, mintparams.to, amount);
    }

    function _useSignature(string calldata stage, bytes calldata signature, MintParams calldata mintparams) internal {
        StageMintInfo memory stageMintInfo = stageToMint[stage];
        if (stageMintInfo.enableSig) {
            // The given signature must not have been used
            if (usedSignatures[signature]) revert SignatureAlreadyUsed();

            if (block.timestamp > mintparams.expiry) revert ExpiredSignature();

            // Mark the signature as used
            usedSignatures[signature] = true;

            // The given signature must be valid
            bytes32 digest;
            {
                bytes32 stageByte32 = keccak256(bytes(stage));
                digest = keccak256(
                    abi.encode(
                        MINT_AUTH_TYPE_HASH,
                        mintparams.to,
                        mintparams.tokenId,
                        mintparams.amount,
                        mintparams.nonce,
                        mintparams.expiry,
                        stageByte32
                    )
                );
            }

            address recoveredSigner = ECDSA.recover(_hashTypedDataV4(digest), signature);
            if (recoveredSigner != signer) revert InvalidSignature();
        }
    }

    function _increaseMintRecord(string calldata stage, address user, uint256 amount) internal {
        totalMintedAmount += amount;
        mintRecord[user][stage] += amount;
        stageToTotalSupply[stage] += amount;
    }

    /// @notice Updates the whitelist signer.
    /// @param signer_ The new whitelist signer address.
    function setSigner(address signer_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        signer = signer_;
        emit SignerUpdated(signer_);
    }

    function setStageMintInfo(StageMintInfo calldata stageMintInfo) external onlyRole(DEFAULT_ADMIN_ROLE) {
        string memory stage = stageMintInfo.stage;

        _stageNonExist(stage);

        stageToMint[stage] = stageMintInfo;

        emit StageMintInfoSet(stageMintInfo);
    }

    function _stageNonExist(string memory stage) internal view {
        bytes memory nameBytes = bytes(stageToMint[stage].stage); // Convert string to bytes
        if (nameBytes.length != 0) {
            revert ExistStage();
        }
    }

    function setStageMintTime(string calldata stage, uint64 startTime, uint64 endTime)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        stageExist(stage)
    {
        stageToMint[stage].startTime = startTime;
        stageToMint[stage].endTime = endTime;

        emit StageMintTimeSet(stage, startTime, endTime);
    }

    function setStageMintLimitationPerAddress(string calldata stage, uint8 mintLimitationPerAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        stageExist(stage)
    {
        stageToMint[stage].limitationForAddress = mintLimitationPerAddress;

        emit StageMintLimitationPerAddressSet(stage, mintLimitationPerAddress);
    }

    function setStageMaxSupply(string calldata stage, uint32 stageMaxSupply)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        stageExist(stage)
    {
        //new total stage supply that be configure
        if (stageMaxSupply > maxSupply || stageMaxSupply <= totalMintedAmount) {
            revert InvalidStageMaxSupply();
        }

        stageToMint[stage].maxSupplyForStage = stageMaxSupply;

        emit StageMaxSupplySet(stage, stageMaxSupply);
    }

    function setMaxSupply(uint32 newMaxSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMaxSupply < totalMintedAmount) {
            revert InvalidMaxSupply();
        }
        maxSupply = newMaxSupply;
        emit MaxSupplySet(newMaxSupply);
    }

    function setStageEnableSig(string calldata stage, bool enableSig)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        stageExist(stage)
    {
        stageToMint[stage].enableSig = enableSig;

        emit StageEnableSigSet(stage, enableSig);
    }

    function _validateActive(string calldata stage) internal view {
        StageMintInfo memory stageMintInfo = stageToMint[stage];
        if (_cast(block.timestamp < stageMintInfo.startTime) | _cast(block.timestamp > stageMintInfo.endTime) == 1) {
            // Revert if the stage is not active.
            revert NotActive();
        }
    }

    function _validateAmount(string calldata stage, address to, uint256 amount) internal view {
        StageMintInfo memory stageMintInfo = stageToMint[stage];
        uint256 mintedAmount = mintRecord[to][stage];
        uint256 mintLimitationPerAddress = stageMintInfo.limitationForAddress;
        uint256 maxSupplyForStage = stageMintInfo.maxSupplyForStage;
        uint256 stageTotalSupply = stageToTotalSupply[stage];

        //check per address mint limitation
        if (mintedAmount + amount > mintLimitationPerAddress) {
            revert ExceedPerAddressLimit();
        }

        //check stage mint maxsupply
        if (maxSupplyForStage > 0 && stageTotalSupply + amount > maxSupplyForStage) {
            revert ExceedMaxSupplyForStage();
        }

        //check total maxSupply
        if (totalMintedAmount + amount > maxSupply) {
            revert ExceedMaxSupply();
        }
    }

    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }

    modifier stageExist(string calldata stage) {
        bytes memory nameBytes = bytes(stageToMint[stage].stage); // Convert string to bytes
        if (nameBytes.length == 0) {
            revert NonExistStage();
        }

        _;
    }
}
