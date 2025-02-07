// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.26;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IOKXMultiMint} from "../interfaces/IOKXMultiMint.sol";

/// @custom:security-contact mr.nmh175@gmail.com
abstract contract OkxMultiRound is IOKXMultiMint, EIP712Upgradeable, AccessControlUpgradeable {
    bytes32 public constant OWNER_CONTRACT = keccak256("OWNER_CONTRACT");

    bytes32 public constant MINT_AUTH_TYPE_HASH =
        keccak256("MintAuth(address to,uint256 tokenId,uint256 amount,uint256 nonce,uint256 expiry,string stage)");

    address public signer;
    mapping(bytes signature => bool used) private usedSignatures;
    mapping(address => mapping(string => uint256)) private _mintRecord; //Address mint record in each stage.
    mapping(string => StageMintInfo) private _stageToMint; // Stage to single stage mint information.
    mapping(string => uint256) private _stageToTotalSupply; // Minted amount for each stage.
    uint256 private totalMaxSupply; // Maximum supply of the NFTs of all stages.
    uint256 public totalMintedAmount;

    constructor() {
        _disableInitializers();
    }

    // TODO: Init all parameters in the initialize function
    function initialize(address owner, address _signer) public initializer {
        __EIP712_init("OKXMint", "1.0");

        _grantRole(OWNER_CONTRACT, owner);

        signer = _signer;
    }

    //////////////////////////////////////////////////////////////////////////////////
    //                               WRITE FUNCTIONS                                //
    //////////////////////////////////////////////////////////////////////////////////

    /// @notice Check if the minting action of a address is eligible.
    /// @param stage The stage name.
    /// @param proof The proof of the minting action.
    ///  signature The signature of the minting action. (not used)
    /// @param mintparams The minting parameters.
    function eligibleCheckingAndRegister(
        string calldata stage,
        bytes32[] calldata proof,
        bytes calldata signature,
        MintParams calldata mintparams
    ) external returns (uint256 amount) {
        amount = mintparams.amount;

        // the stage data
        StageMintInfo memory stageMintInfo = _stageToMint[stage];

        // if this round is not public, the proof must be valid
        if (stageMintInfo.mintType != IOKXMultiMint.MintType.Public) {
            if (
                !MerkleProof.verify(proof, stageMintInfo.allowListMerkleRoot, keccak256(abi.encodePacked(mintparams.to)))
            ) {
                revert NotWhitelisted();
            }
        }

        _useSignature(stage, signature, mintparams);

        _validateActive(stage);
        _validateAmount(stage, mintparams.to, amount);
        _increaseMintRecord(stage, mintparams.to, amount);
    }

    /// @notice Updates the whitelist signer.
    /// @param signer_ The new whitelist signer address.
    function setSigner(address signer_) external onlyRole(OWNER_CONTRACT) {
        signer = signer_;
    }

    /// @notice Configure or update the maximum number of nfts that can be minted.
    /// @param newMaxSupply The new maximum number of nfts that can be minted.
    function setMaxSupply(uint256 newMaxSupply) external onlyRole(OWNER_CONTRACT) {
        totalMaxSupply = newMaxSupply;
        emit MaxSupplySet(uint32(newMaxSupply));
    }

    /// @notice Configure or update the information of a certain round according to the stage
    /// @param stageMintInfo The mint information for the stage.
    function setStageMintInfo(IOKXMultiMint.StageMintInfo calldata stageMintInfo) external onlyRole(OWNER_CONTRACT) {
        string memory stage = stageMintInfo.stage;

        _stageNonExist(stage);

        _stageToMint[stage] = stageMintInfo;

        // update the total max supply
        totalMaxSupply += stageMintInfo.maxSupplyForStage;

        emit StageMintInfoSet(stageMintInfo);
    }

    /// @notice Configure or update the mint time for a specific stage.
    /// @param stage Round identification.
    /// @param startTime The start time of the stage.
    /// @param endTime The end time of the stage.
    function setStageMintTime(string calldata stage, uint64 startTime, uint64 endTime)
        external
        onlyRole(OWNER_CONTRACT)
        stageExist(stage)
    {
        // The start time must be less than the end time and greater than the current time.
        if (startTime >= endTime || startTime < block.timestamp) {
            revert InvalidTime();
        }

        _stageToMint[stage].startTime = startTime;
        _stageToMint[stage].endTime = endTime;

        emit StageMintTimeSet(stage, startTime, endTime);
    }

    /// @notice According to the stage, set the maximum nft supply for a specific round.
    /// @param stage Round identification.
    /// @param _maxSupply nft maximum supply.
    function setStageMaxSupply(string calldata stage, uint32 _maxSupply)
        external
        onlyRole(OWNER_CONTRACT)
        stageExist(stage)
    {
        //new total stage must be less than or equal to the total maxSupply
        if (totalMaxSupply < _maxSupply) {
            revert InvalidStageMaxSupply();
        }

        // The max supply must be updated following the new total stage supply
        totalMaxSupply -= _stageToMint[stage].maxSupplyForStage;
        totalMaxSupply += _maxSupply;

        // The new total stage supply that be configure
        _stageToMint[stage].maxSupplyForStage = _maxSupply;

        emit StageMaxSupplySet(stage, _maxSupply);
    }

    /// @notice Set payment information for a specific round based on the stage
    /// @param stage Round identification.
    /// @param payeeAddress Payment address.
    /// @param paymentToken Token contract address for payment (if 0, it is a native token).
    /// @param price Single nft price.
    function setStagePayment(string calldata stage, address payeeAddress, address paymentToken, uint256 price)
        external
        onlyRole(OWNER_CONTRACT)
        stageExist(stage)
    {
        // the new payee address must be not zero address
        if (payeeAddress == address(0)) {
            revert InvalidPayeeAddress();
        }
        _stageToMint[stage].payeeAddress = payeeAddress;

        // update new payment token
        _stageToMint[stage].paymentToken = paymentToken;

        // update new price
        _stageToMint[stage].price = price;
    }

    /// @notice Set the upper limit of the number of mints per address for a specific round according to the stage
    /// @param stage Round identification.
    /// @param mintLimitationPerAddress Single address mint limit.
    function setStageMintLimitationPerAddress(string calldata stage, uint8 mintLimitationPerAddress)
        external
        onlyRole(OWNER_CONTRACT)
        stageExist(stage)
    {
        _stageToMint[stage].limitationForAddress = mintLimitationPerAddress;

        emit StageMintLimitationPerAddressSet(stage, mintLimitationPerAddress);
    }

    /// @notice Set whether server level signing is enabled for a specific round according to the stage
    /// @param stage Round identification.
    /// @param enableSig Whether to enable (true, false).
    function setStageEnableSig(string calldata stage, bool enableSig)
        external
        onlyRole(OWNER_CONTRACT)
        stageExist(stage)
    {
        _stageToMint[stage].enableSig = enableSig;
    }

    /// @notice Set a valid signer address.
    ///     If the address has been configured, it is a modify function.abi
    ///     If the address has not been configured, then it is an add function to configure the address.
    /// @param _signer Signer address.
    /// @param status Effective status.
    function setActiveSigner(address _signer, bool status) external onlyRole(OWNER_CONTRACT) {
        if (status) {
            signer = _signer;
        } else {
            if (signer == _signer) {
                signer = address(0);
            }
        }
    }

    /// @notice Set whether to restrict transfer, if configured to true, transfer is not allowed.
    ///     Otherwise, transfer is allowed.
    /// @param isTransferRestricted_ Whether to restrict transfer.
    /// @param startTime Start time.
    /// @param endTime End time.
    function setTransferRestricted(bool isTransferRestricted_, uint64 startTime, uint64 endTime)
        external
        onlyRole(OWNER_CONTRACT)
    {
        // We are not using this function in the current implementation.
    }

    //////////////////////////////////////////////////////////////////////////////////
    //                               READ FUNCTIONS                                 //
    //////////////////////////////////////////////////////////////////////////////////

    /// @notice Query the total number of minted under the current stage
    /// @param stage The stage name
    function stageToTotalSupply(string memory stage) external view returns (uint256) {
        return _stageToTotalSupply[stage];
    }

    /// @notice Query the quantity that has been minted at a certain stage at a certain address
    /// @param to Inquiry address
    /// @param stage The stage name
    function mintRecord(address to, string memory stage) external view returns (uint256) {
        return _mintRecord[to][stage];
    }

    /// @notice Query the total mint quantity
    function totalSupply() external view returns (uint256) {
        return totalMintedAmount;
    }

    /// @notice Query configuration information for a specific stage
    /// @param stage The stage name
    function stageToMint(string memory stage) external view returns (IOKXMultiMint.StageMintInfo memory) {
        return _stageToMint[stage];
    }

    /// @notice Query the maximum number of total mints
    function maxSupply() external view returns (uint256) {
        return totalMaxSupply;
    }

    //////////////////////////////////////////////////////////////////////////////////
    //                      internal functions and modifiers                        //
    //////////////////////////////////////////////////////////////////////////////////

    function _useSignature(string calldata stage, bytes calldata signature, MintParams calldata mintparams) internal {
        StageMintInfo memory stageMintInfo = _stageToMint[stage];
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
        _mintRecord[user][stage] += amount;
        _stageToTotalSupply[stage] += amount;
    }

    function _validateActive(string calldata stage) internal view {
        StageMintInfo memory stageMintInfo = _stageToMint[stage];
        if (_cast(block.timestamp < stageMintInfo.startTime) | _cast(block.timestamp > stageMintInfo.endTime) == 1) {
            // Revert if the stage is not active.
            revert NotActive();
        }
    }

    function _validateAmount(string calldata stage, address to, uint256 amount) internal view {
        StageMintInfo memory stageMintInfo = _stageToMint[stage];
        uint256 mintedAmount = _mintRecord[to][stage];
        uint256 mintLimitationPerAddress = stageMintInfo.limitationForAddress;
        uint256 maxSupplyForStage = stageMintInfo.maxSupplyForStage;
        uint256 stageTotalSupply = _stageToTotalSupply[stage];

        //check per address mint limitation
        if (mintedAmount + amount > mintLimitationPerAddress) {
            revert ExceedPerAddressLimit();
        }

        //check stage mint maxsupply
        if (maxSupplyForStage > 0 && stageTotalSupply + amount > maxSupplyForStage) {
            revert ExceedMaxSupplyForStage();
        }

        //check total maxSupply
        if (totalMintedAmount + amount > totalMaxSupply) {
            revert ExceedMaxSupply();
        }
    }

    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }

    function _stageNonExist(string memory stage) internal view {
        bytes memory nameBytes = bytes(_stageToMint[stage].stage); // Convert string to bytes
        if (nameBytes.length != 0) {
            revert ExistStage();
        }
    }

    modifier stageExist(string calldata stage) {
        bytes memory nameBytes = bytes(_stageToMint[stage].stage); // Convert string to bytes
        if (nameBytes.length == 0) {
            revert NonExistStage();
        }

        _;
    }
}
