// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IOkxMultiRound} from "./IOkxMultiRound.sol";

/// @title Story NFT Interface
/// @notice A Story NFT is a soulbound NFT that has an unified token URI for all tokens.
interface IPunkNFT is IOkxMultiRound {
    ////////////////////////////////////////////////////////////////////////////
    //                              Structs                                   //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Struct for custom data for initializing the PunkNFT contract.
    /// @param tokenURI The token URI for all NFTs (follows OpenSea metadata standard).
    /// @param signer The signer of the whitelist signatures.
    /// @param ipMetadataURI The URI of the metadata for all IP from this collection.
    /// @param ipMetadataHash The hash of the metadata for all IP from this collection.
    /// @param nftMetadataHash The hash of the metadata for all IP NFTs from this collection.
    struct CustomInitParams {
        string tokenURI;
        address signer;
        string ipMetadataURI;
        bytes32 ipMetadataHash;
        bytes32 nftMetadataHash;
    }
    ////////////////////////////////////////////////////////////////////////////
    //                              Events                                    //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Emitted when a NFT is minted.
    /// @param recipient The address of the recipient of the NFT.
    /// @param tokenId The token ID of the minted NFT.
    /// @param ipId The ID of the NFT IP.

    event PunkNFTMinted(address recipient, uint256 tokenId, address ipId);

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
        MintParams calldata mintparams
    ) external returns (uint256 tokenId, address ipId);

    /// @notice Set the Id of the root IP.
    /// @param ipId The ID of the root IP.
    function setRootIpId(address ipId) external;
}
