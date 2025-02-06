// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.26;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IDerivativeWorkflows} from
    "@story-protocol/protocol-periphery-v1.3.0/contracts/interfaces/workflows/IDerivativeWorkflows.sol";
import {WorkflowStructs} from "@story-protocol/protocol-periphery-v1.3.0/contracts/lib/WorkflowStructs.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISimpleERC721} from "./interfaces/ISimpleERC721.sol";
import {IMimbokuMultiround} from "./interfaces/IMimbokuMultiround.sol";
import {IOKXMultiMint} from "./interfaces/IOKXMultiMint.sol";

contract MimbokuMultiround is IMimbokuMultiround, Initializable, AccessControlUpgradeable {
    /// We need a NFT contract to mint NFTs
    address public NFT_CONTRACT;

    /// We need a MultiRound contract to manage rounds
    address public MULTIROUND_CONTRACT;

    /// @notice The default license terms ID.
    uint256 public DEFAULT_LICENSE_TERMS_ID;

    /// @notice Story Proof-of-Creativity PILicense Template address.
    address public PIL_TEMPLATE;

    /// @notice The DerivativeWorkflows contract address.
    address public DERIVATIVE_WORKFLOWS;

    /// @notice Root NFT
    RootNFT public rootNFT;

    /// @notice IP information
    string public ipMetadataURI;
    bytes32 public ipMetadataHash;

    /// @notice The list of the rest token_id
    uint256[] private remainingTokenIds;

    /// @notice Number of remaining token_id
    uint256 private remainingTokenIdCount;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address nftContract,
        address multiRoundContract,
        IPMetadata calldata ipMetadata
    ) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        // The NFT collection contract
        NFT_CONTRACT = nftContract;

        // The MultiRound contract for managing minting
        MULTIROUND_CONTRACT = multiRoundContract;

        // The ip metadata
        rootNFT = ipMetadata.rootNFT;

        DEFAULT_LICENSE_TERMS_ID = ipMetadata.defaultLicenseTermsId;
        PIL_TEMPLATE = ipMetadata.pilTemplate;
        DERIVATIVE_WORKFLOWS = ipMetadata.derivativeWorkflows;

        ipMetadataURI = ipMetadata.ipMetadataURI;
        ipMetadataHash = ipMetadata.ipMetadataHash;
    }

    //////////////////////////////////////////////////////////////////////////////////
    //                               WRITE FUNCTIONS                                //
    //////////////////////////////////////////////////////////////////////////////////

    /// @notice Configure or update the information of a certain round according to the stage
    /// @param stageMintInfo The mint information for the stage.
    function setStageMintInfo(IOKXMultiMint.StageMintInfo calldata stageMintInfo) external {
        IOKXMultiMint(MULTIROUND_CONTRACT).setStageMintInfo(stageMintInfo);

        // update the remaining token_id list
        uint256 maxSupply = IOKXMultiMint(MULTIROUND_CONTRACT).maxSupply();
        delete remainingTokenIds; // Clear storage before re-allocating
        remainingTokenIds = new uint256[](maxSupply); // Allocate storage

        remainingTokenIdCount = maxSupply;
    }

    /// @notice Configure or update the mint time for a specific stage.
    /// @param stage Round identification.
    /// @param startTime The start time of the stage.
    /// @param endTime The end time of the stage.
    function setStageMintTime(string calldata stage, uint64 startTime, uint64 endTime) external {
        IOKXMultiMint(MULTIROUND_CONTRACT).setStageMintTime(stage, startTime, endTime);
    }

    /// @notice According to the stage, set the maximum nft supply for a specific round.
    /// @param stage Round identification.
    /// @param maxSupply nft maximum supply.
    function setStageMaxSupply(string calldata stage, uint32 maxSupply) external {
        IOKXMultiMint(MULTIROUND_CONTRACT).setStageMaxSupply(stage, maxSupply);
    }

    /// @notice Set payment information for a specific round based on the stage
    /// @param stage Round identification.
    /// @param payeeAddress Payment address.
    /// @param paymentToken Token contract address for payment (if 0, it is a native token).
    /// @param price Single nft price.
    function setStagePayment(string calldata stage, address payeeAddress, address paymentToken, uint64 price)
        external
    {
        IOKXMultiMint(MULTIROUND_CONTRACT).setStagePayment(stage, payeeAddress, paymentToken, price);
    }

    /// @notice Set the upper limit of the number of mints per address for a specific round according to the stage
    /// @param stage Round identification.
    /// @param mintLimitationPerAddress Single address mint limit.
    function setStageMintLimitationPerAddress(string calldata stage, uint8 mintLimitationPerAddress) external {
        IOKXMultiMint(MULTIROUND_CONTRACT).setStageMintLimitationPerAddress(stage, mintLimitationPerAddress);
    }

    /// @notice Set whether server level signing is enabled for a specific round according to the stage
    /// @param stage Round identification.
    /// @param enableSig Whether to enable (true, false).
    function setStageEnableSig(string calldata stage, bool enableSig) external {
        IOKXMultiMint(MULTIROUND_CONTRACT).setStageEnableSig(stage, enableSig);
    }

    /// @notice Set a valid signer address.
    ///     If the address has been configured, it is a modify function.abi
    ///     If the address has not been configured, then it is and add function to configure the address.
    /// @param signer Signer address.
    /// @param status Effective status.
    function setActiveSigner(address signer, bool status) external {
        IOKXMultiMint(MULTIROUND_CONTRACT).setActiveSigner(signer, status);
    }

    /// @notice Set whether to restrict transfer, if configured to true, transfer is not allowed.
    ///     Otherwise, transfer is allowed.
    /// @param isTransferRestricted_ Whether to restrict transfer.
    /// @param startTime Start time.
    /// @param endTime End time.
    function setTransferRestricted(bool isTransferRestricted_, uint64 startTime, uint64 endTime) external {
        IOKXMultiMint(MULTIROUND_CONTRACT).setTransferRestricted(isTransferRestricted_, startTime, endTime);
    }

    /// @notice Mints a NFT for the given recipient, registers it as an IP,
    ///         and makes it a derivative of the organization IP.
    /// @param stage         Identification of the stage
    /// @param signature     The signature from the whitelist signer. This signautre is genreated by having the whitelist
    /// @param proof         The proof for the leaf of the allowlist in a stage if mint type is Allowlist.
    /// @param mintparams    The mint parameter
    /// signer sign the caller's address (msg.sender) for this `mint` function.
    /// @return tokenId The token ID of the minted NFT.
    /// @return ipId The ID of the NFT IP.
    function mint(
        string calldata stage,
        bytes calldata signature,
        bytes32[] calldata proof,
        IOKXMultiMint.MintParams calldata mintparams
    ) external payable returns (uint256 tokenId, address ipId) {
        // register minting with OKX MultiRound, and get the remaining amount to mint
        uint256 amount =
            IOKXMultiMint(MULTIROUND_CONTRACT).eligibleCheckingAndRegister(stage, proof, signature, mintparams);

        // get stage payment information
        IOKXMultiMint.StageMintInfo memory stageMintInfo = IOKXMultiMint(MULTIROUND_CONTRACT).stageToMint(stage);
        address paymentToken = stageMintInfo.paymentToken;
        address payeeAddress = stageMintInfo.payeeAddress;
        uint256 nftPrice = stageMintInfo.price;

        if (nftPrice != 0) {
            if (paymentToken != address(0)) {
                // ERC20 token transfer
                require(
                    IERC20(paymentToken).transferFrom(msg.sender, payeeAddress, nftPrice * amount),
                    "Transfer ERC20 failed"
                );
            } else {
                // native token transfer
                require(msg.value >= nftPrice * amount, "Incorrect native payment amount");
                payable(payeeAddress).transfer(msg.value);
            }
        }

        for (uint256 i = 0; i < amount; ++i) {
            // Mint NFt to the contract itself and register it as an IP
            (tokenId, ipId) = _mintToSelf();

            // Transfer NFT to the recipient
            ISimpleERC721(NFT_CONTRACT).transferFrom(address(this), mintparams.to, tokenId);
        }

        emit NFTMinted(mintparams.to, tokenId, ipId);
    }

    //////////////////////////////////////////////////////////////////////////////////
    //                               READ FUNCTIONS                                 //
    //////////////////////////////////////////////////////////////////////////////////

    /// @notice Query the total number of minted under the current stage
    /// @param stage The stage name
    function stageToTotalSupply(string memory stage) external view returns (uint256) {
        return IOKXMultiMint(MULTIROUND_CONTRACT).stageToTotalSupply(stage);
    }

    /// @notice Query the quantity that has been minted at a certain stage at a certain address
    /// @param to Inquiry address
    /// @param stage The stage name
    function mintRecord(address to, string memory stage) external view returns (uint256) {
        return IOKXMultiMint(MULTIROUND_CONTRACT).mintRecord(to, stage);
    }

    /// @notice Query the total mint quantity
    function totalSupply() external view returns (uint256) {
        return IOKXMultiMint(MULTIROUND_CONTRACT).totalSupply();
    }

    /// @notice Query configuration information for a specific stage
    /// @param stage The stage name
    function stageToMint(string memory stage) external view returns (IOKXMultiMint.StageMintInfo memory) {
        return IOKXMultiMint(MULTIROUND_CONTRACT).stageToMint(stage);
    }

    //////////////////////////////////////////////////////////////////////////////////
    //                             Internal functions                               //
    //////////////////////////////////////////////////////////////////////////////////

    /// @notice Mints an NFT to the contract itself.
    /// @return tokenId The token ID of the minted NFT.
    /// @return ipId The IP ID of the minted NFT.
    function _mintToSelf() internal returns (uint256 tokenId, address ipId) {
        tokenId = _getRandomId();

        ISimpleERC721(NFT_CONTRACT).safeMint(address(this), tokenId);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = rootNFT.ipId;
        licenseTermsIds[0] = DEFAULT_LICENSE_TERMS_ID;

        // register and make derivative IP
        ipId = IDerivativeWorkflows(DERIVATIVE_WORKFLOWS).registerIpAndMakeDerivative(
            NFT_CONTRACT,
            tokenId,
            WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: PIL_TEMPLATE,
                licenseTermsIds: licenseTermsIds,
                royaltyContext: "",
                maxMintingFee: 0,
                maxRts: 0,
                maxRevenueShare: 0
            }),
            WorkflowStructs.IPMetadata({
                ipMetadataURI: ipMetadataURI,
                ipMetadataHash: ipMetadataHash,
                nftMetadataURI: "", // this parameter is token URI, but seen `nftMetadataHash` is not used in the function, so let it be empty
                nftMetadataHash: "" // this parameter must be passed through the mint function, otherwise let it be empty
            }),
            WorkflowStructs.SignatureData({signer: address(0), deadline: 0, signature: new bytes(0)})
        );
    }

    function _getRandomId() internal returns (uint256) {
        uint256 rand =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % remainingTokenIdCount;

        uint256 tokenId = remainingTokenIds[rand] == 0 ? (rand + 1) : remainingTokenIds[rand];

        // swap the last element with the selected element
        remainingTokenIds[rand] = remainingTokenIds[remainingTokenIdCount - 1] == 0
            ? remainingTokenIdCount
            : remainingTokenIds[remainingTokenIdCount - 1];

        // decrease the remaining token count
        --remainingTokenIdCount;

        return tokenId;
    }
}
