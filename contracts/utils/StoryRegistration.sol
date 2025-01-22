// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ICoreMetadataModule} from
    "@story-protocol/protocol-core-v1.2.3/contracts/interfaces/modules/metadata/ICoreMetadataModule.sol";
import {IIPAssetRegistry} from
    "@story-protocol/protocol-core-v1.2.3/contracts/interfaces/registries/IIPAssetRegistry.sol";
// /*solhint-disable-next-line max-line-length*/
import {ILicensingModule} from
    "@story-protocol/protocol-core-v1.2.3/contracts/interfaces/modules/licensing/ILicensingModule.sol";

abstract contract StoryRegistration {
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

    /// @notice Story Proof-of-Creativity IP Asset Registry address.
    IIPAssetRegistry public IP_ASSET_REGISTRY;

    /// @notice Story Proof-of-Creativity Licensing Module address.
    ILicensingModule public LICENSING_MODULE;

    /// @notice Core Metadata Module address.
    ICoreMetadataModule public CORE_METADATA_MODULE;

    /// @notice Story Proof-of-Creativity PILicense Template address.
    address public PIL_TEMPLATE;

    /// @notice The default license terms ID.
    uint256 public DEFAULT_LICENSE_TERMS_ID;

    error ZeroAddressParam();
    error CallerNotTokenOwner();

    string public ipMetadataURI;
    bytes32 public ipMetadataHash;
    bytes32 public nftMetadataHash;
    address public rootIpId;

    function __StoryRegistration_init(
        address ipAssetRegistry,
        address licensingModule,
        address coreMetadataModule,
        address pilTemplate,
        uint256 defaultLicenseTermId,
        CustomInitParams calldata customInitParams
    ) internal {
        if (ipAssetRegistry == address(0) || licensingModule == address(0) || coreMetadataModule == address(0)) {
            revert ZeroAddressParam();
        }
        IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        CORE_METADATA_MODULE = ICoreMetadataModule(coreMetadataModule);

        PIL_TEMPLATE = pilTemplate;

        DEFAULT_LICENSE_TERMS_ID = defaultLicenseTermId;

        ipMetadataURI = customInitParams.ipMetadataURI;
        ipMetadataHash = customInitParams.ipMetadataHash;
        nftMetadataHash = customInitParams.nftMetadataHash;
    }

    /// @notice Register and NFT as an IP asset.
    /// @param tokenId The ID of the token to register
    /// @return ipId The ID of the newly created IP.
    function _registerIp(uint256 tokenId) internal virtual returns (address ipId) {
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(this), tokenId);

        // set the IP metadata if they are not empty
        if (
            keccak256(abi.encodePacked(ipMetadataURI)) != keccak256("") || ipMetadataHash != bytes32(0)
                || nftMetadataHash != bytes32(0)
        ) {
            ICoreMetadataModule(CORE_METADATA_MODULE).setAll(ipId, ipMetadataURI, ipMetadataHash, nftMetadataHash);
        }
    }

    /// @notice Register `ipId` as a derivative of `parentIpIds` under `licenseTemplate` with `licenseTermsIds`.
    /// @param ipId The ID of the IP to be registered as a derivative.
    /// @param parentIpIds The IDs of the parent IPs.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @param royaltyContext The royalty context, should be empty for Royalty Policy LAP.
    function _makeDerivative(
        address ipId,
        address[] memory parentIpIds,
        address licenseTemplate,
        uint256[] memory licenseTermsIds,
        bytes memory royaltyContext
    ) internal virtual {
        LICENSING_MODULE.registerDerivative({
            childIpId: ipId,
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: licenseTemplate,
            royaltyContext: royaltyContext
        });
    }
}
