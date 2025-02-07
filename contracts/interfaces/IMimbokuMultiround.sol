// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IOKXMultiMint} from "./IOKXMultiMint.sol";

/// @title Story NFT Interface
/// @notice A Story NFT is a soulbound NFT that has an unified token URI for all tokens.
interface IMimbokuMultiround {
    /// @dev Structure for the root IP
    /// @param contract_address The root NFT contract address.
    /// @param tokenId The root NFT token ID.
    /// @param ipId The root IP ID.
    struct RootNFT {
        address contract_address;
        uint256 tokenId;
        address ipId;
    }

    /// @dev Structure for the initial contract IP parameters
    /// @param ipMetadataURI The URI of the metadata for all IP from this collection.
    /// @param ipMetadataHash The hash of the metadata for all IP from this collection.
    struct IPMetadata {
        RootNFT rootNFT;
        uint256 defaultLicenseTermsId;
        address pilTemplate;
        address derivativeWorkflows;
        string ipMetadataURI;
        bytes32 ipMetadataHash;
    }

    ////////////////////////////////////////////////////////////////////////////
    //                              Events                                    //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Emitted when a NFT is minted.
    /// @param recipient The address of the recipient of the NFT.
    /// @param tokenId The token ID of the minted NFT.
    /// @param ipId The ID of the NFT IP.

    event NFTMinted(address recipient, uint256 tokenId, address ipId);

    //////////////////////////////////////////////////////////////////////////////////
    //                               WRITE FUNCTIONS                                //
    //////////////////////////////////////////////////////////////////////////////////

    /// @notice Updates the whitelist signer.
    /// @param signer_ The new whitelist signer address.
    function setSigner(address signer_) external;

    /// @notice Configure or update the maximum number of nfts that can be minted.
    /// @param newMaxSupply The new maximum number of nfts that can be minted.
    function setMaxSupply(uint256 newMaxSupply) external;

    /// @notice Configure or update the information of a certain round according to the stage
    /// @param stageMintInfo The mint information for the stage.
    function setStageMintInfo(IOKXMultiMint.StageMintInfo calldata stageMintInfo) external;

    /// @notice Configure or update the mint time for a specific stage.
    /// @param stage Round identification.
    /// @param startTime The start time of the stage.
    /// @param endTime The end time of the stage.
    function setStageMintTime(string calldata stage, uint64 startTime, uint64 endTime) external;

    /// @notice According to the stage, set the maximum nft supply for a specific round.
    /// @param stage Round identification.
    /// @param maxSupply nft maximum supply.
    function setStageMaxSupply(string calldata stage, uint32 maxSupply) external;

    /// @notice Set payment information for a specific round based on the stage
    /// @param stage Round identification.
    /// @param payeeAddress Payment address.
    /// @param paymentToken Token contract address for payment (if 0, it is a native token).
    /// @param price Single nft price.
    function setStagePayment(string calldata stage, address payeeAddress, address paymentToken, uint64 price)
        external;

    /// @notice Set the upper limit of the number of mints per address for a specific round according to the stage
    /// @param stage Round identification.
    /// @param mintLimitationPerAddress Single address mint limit.
    function setStageMintLimitationPerAddress(string calldata stage, uint8 mintLimitationPerAddress) external;

    /// @notice Set whether server level signing is enabled for a specific round according to the stage
    /// @param stage Round identification.
    /// @param enableSig Whether to enable (true, false).
    function setStageEnableSig(string calldata stage, bool enableSig) external;

    /// @notice Set a valid signer address.
    ///     If the address has been configured, it is a modify function.abi
    ///     If the address has not been configured, then it is and add function to configure the address.
    /// @param signer Signer address.
    /// @param status Effective status.
    function setActiveSigner(address signer, bool status) external;

    /// @notice Set whether to restrict transfer, if configured to true, transfer is not allowed.
    ///     Otherwise, transfer is allowed.
    /// @param isTransferRestricted_ Whether to restrict transfer.
    /// @param startTime Start time.
    /// @param endTime End time.
    function setTransferRestricted(bool isTransferRestricted_, uint64 startTime, uint64 endTime) external;

    /// @notice Mints a NFT for the given recipient, registers it as an IP,
    ///         and makes it a derivative of the organization IP.
    /// @param stage         Identification of the stage
    /// @param signature     The signature from the whitelist signer. This signautre is genreated by having the whitelist
    /// the 3rd param, proof, is the proof for the leaf of the allowlist in a stage if mint type is Allowlist.
    /// @param mintparams    The mint parameter
    /// signer sign the caller's address (msg.sender) for this `mint` function.
    /// @return tokenId The token ID of the minted NFT.
    /// @return ipId The ID of the NFT IP.
    function mint(
        string calldata stage,
        bytes calldata signature,
        bytes32[] calldata proof,
        IOKXMultiMint.MintParams calldata mintparams
    ) external payable returns (uint256 tokenId, address ipId);

    //////////////////////////////////////////////////////////////////////////////////
    //                               READ FUNCTIONS                                 //
    //////////////////////////////////////////////////////////////////////////////////

    /// @notice Query the total number of minted under the current stage
    /// @param stage The stage name
    function stageToTotalSupply(string memory stage) external view returns (uint256);

    /// @notice Query the quantity that has been minted at a certain stage at a certain address
    /// @param to Inquiry address
    /// @param stage The stage name
    function mintRecord(address to, string memory stage) external view returns (uint256);

    /// @notice Query the total mint quantity
    function totalSupply() external view returns (uint256);

    /// @notice Query configuration information for a specific stage
    /// @param stage The stage name
    function stageToMint(string memory stage) external view returns (IOKXMultiMint.StageMintInfo memory);
}
