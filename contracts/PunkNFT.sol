// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {StoryUtil} from "./story-nft/StoryUtil.sol";
import {IPunkNFT} from "./interfaces/IPunkNFT.sol";

/// @custom:security-contact mr.nmh175@gmail.com
contract PunkNFT is
    Initializable,
    IPunkNFT,
    ERC721PausableUpgradeable,
    EIP712Upgradeable,
    AccessControlUpgradeable,
    StoryUtil
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    bytes32 public constant MINT_AUTH_TYPE_HASH =
        keccak256("MintAuth(address to,uint256 tokenId,uint256 amount,uint256 nonce,uint256 expiry,string stage)");

    // PunkNFTStorage private _punkNFTStorage;
    address public signer;
    string public ipMetadataURI;
    bytes32 public ipMetadataHash;
    bytes32 public nftMetadataHash;
    mapping(bytes signature => bool used) public usedSignatures;
    mapping(address => mapping(string => uint256)) public mintRecord; //Address mint record in each stage.
    mapping(string => StageMintInfo) public stageToMint; // Stage to single stage mint information.
    mapping(string => uint256) public stageToTotalSupply; //Minted amount for each stage.
    uint256 public maxSupply;

    address public rootIpId;

    uint256 private _nextTokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address pauser,
        address minter,
        address ipAssetRegistry,
        address licensingModule,
        address coreMetadataModule,
        address pilTemplate,
        uint256 defaultLicenseTermsId,
        CustomInitParams calldata customInitParams
    ) public initializer {
        __ERC721_init("PunkNFT", "PNFT");
        __ERC721Pausable_init();
        __AccessControl_init();
        __EIP712_init("PunkNFT", "1.0");

        __StoryUtil_init(ipAssetRegistry, licensingModule, coreMetadataModule, pilTemplate, defaultLicenseTermsId);

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);

        ipMetadataURI = customInitParams.ipMetadataURI;
        ipMetadataHash = customInitParams.ipMetadataHash;
        nftMetadataHash = customInitParams.nftMetadataHash;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Mints a badge for the given recipient, registers it as an IP,
    ///         and makes it a derivative of the organization IP.
    /// @param stage         Identification of the stage
    /// @param signature     The signature from the whitelist signer. This signautre is genreated by having the whitelist
    /// the 3rd param, proof, is the proof for the leaf of the allowlist in a stage if mint type is Allowlist.
    /// @param mintparams    The mint parameter
    /// signer sign the caller's address (msg.sender) for this `mint` function.
    /// @return tokenId The token ID of the minted badge NFT.
    /// @return ipId The ID of the badge NFT IP.
    function mint(
        string calldata stage,
        bytes calldata signature,
        bytes32[] calldata, /* proof */
        MintParams calldata mintparams
    ) external returns (uint256 tokenId, address ipId) {
        StageMintInfo memory stageMintInfo = stageToMint[stage];
        address to = mintparams.to;
        uint256 amount = mintparams.amount;

        if (stageMintInfo.enableSig) {
            uint256 expiry = mintparams.expiry;
            // The given signature must not have been used
            if (usedSignatures[signature]) revert PunkNFT__SignatureAlreadyUsed();

            if (block.timestamp > expiry) revert ExpiredSignature();

            // Mark the signature as used
            usedSignatures[signature] = true;

            // The given signature must be valid
            bytes32 digest;
            {
                bytes32 stageByte32 = keccak256(bytes(stage));
                digest = keccak256(
                    abi.encode(
                        MINT_AUTH_TYPE_HASH, to, mintparams.tokenId, amount, mintparams.nonce, expiry, stageByte32
                    )
                );
            }

            address recoveredSigner = ECDSA.recover(_hashTypedDataV4(digest), signature);
            if (recoveredSigner != signer) revert PunkNFT__InvalidSignature();
        }

        // Ensure that the mint stage status.
        _validateActive(stageMintInfo.startTime, stageMintInfo.endTime);

        //validate mint amount
        {
            uint256 mintedAmount = mintRecord[to][stage];
            uint256 stageSupply = stageToTotalSupply[stage];
            _validateAmount(
                amount, mintedAmount, stageMintInfo.limitationForAddress, stageMintInfo.maxSupplyForStage, stageSupply
            );
        }

        for (uint256 i = 0; i < amount; ++i) {
            (tokenId, ipId) = _mintToSelf();

            // Transfer NFT to the recipient
            _transfer(address(this), to, tokenId);
        }
        mintRecord[to][stage] += amount;
        stageToTotalSupply[stage] += amount;

        emit PunkNFTMinted(to, tokenId, ipId);
    }

    function setRootIpId(address ipId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rootIpId = ipId;
    }

    function setStageMintInfo(StageMintInfo calldata stageMintInfo) external onlyRole(DEFAULT_ADMIN_ROLE) {
        string memory stage = stageMintInfo.stage;

        _stageNonExist(stage);

        stageToMint[stage] = stageMintInfo;

        emit StageMintInfoSet(stageMintInfo);
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
        if (stageMaxSupply > maxSupply || stageMaxSupply <= _nextTokenId) {
            revert InvalidStageMaxSupply();
        }

        stageToMint[stage].maxSupplyForStage = stageMaxSupply;

        emit StageMaxSupplySet(stage, stageMaxSupply);
    }

    function setMaxSupply(uint32 newMaxSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMaxSupply < _nextTokenId) {
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

    function _validateActive(uint256 startTime, uint256 endTime) internal view {
        if (_cast(block.timestamp < startTime) | _cast(block.timestamp > endTime) == 1) {
            // Revert if the stage is not active.
            revert NotActive();
        }
    }

    function _stageNonExist(string memory stage) internal view {
        bytes memory nameBytes = bytes(stageToMint[stage].stage); // Convert string to bytes
        if (nameBytes.length != 0) {
            revert ExistStage();
        }
    }

    function _validateAmount(
        uint256 amount,
        uint256 mintedAmount,
        uint256 mintLimitationPerAddress,
        uint256 maxSupplyForStage,
        uint256 stageTotalSupply
    ) internal view {
        //check per address mint limitation
        if (mintedAmount + amount > mintLimitationPerAddress) {
            revert ExceedPerAddressLimit();
        }

        //check stage mint maxsupply
        if (maxSupplyForStage > 0 && stageTotalSupply + amount > maxSupplyForStage) {
            revert ExceedMaxSupplyForStage();
        }

        //check total maxSupply
        if (_nextTokenId + amount > maxSupply) {
            revert ExceedMaxSupply();
        }
    }

    /// @notice Mints an NFT to the contract itself.
    /// @return tokenId The token ID of the minted NFT.
    /// @return ipId The IP ID of the minted NFT.
    function _mintToSelf() internal returns (uint256 tokenId, address ipId) {
        tokenId = ++_nextTokenId;
        _safeMint(address(this), tokenId);

        ipId = _registerIp(tokenId, ipMetadataURI, ipMetadataHash, nftMetadataHash);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = rootIpId;
        licenseTermsIds[0] = DEFAULT_LICENSE_TERMS_ID;

        // Make the NFT a derivative of the root IP
        _makeDerivative(ipId, parentIpIds, PIL_TEMPLATE, licenseTermsIds, "");
    }

    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    modifier stageExist(string calldata stage) {
        bytes memory nameBytes = bytes(stageToMint[stage].stage); // Convert string to bytes
        if (nameBytes.length == 0) {
            revert NonExistStage();
        }

        _;
    }
}
