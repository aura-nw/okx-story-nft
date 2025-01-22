// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.26;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OkxMultiRound} from "./utils/OkxMultiRound.sol";
import {StoryRegistration} from "./utils/StoryRegistration.sol";
import {IPunkNFT} from "./interfaces/IPunkNFT.sol";

/// @custom:security-contact mr.nmh175@gmail.com
contract PunkNFT is IPunkNFT, ERC721Upgradeable, AccessControlUpgradeable, StoryRegistration, OkxMultiRound {
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
        __AccessControl_init();
        __OkxMultiRound_init(customInitParams.signer, 10000);

        __StoryRegistration_init(
            ipAssetRegistry, licensingModule, coreMetadataModule, pilTemplate, defaultLicenseTermsId, customInitParams
        );

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
    }

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
        bytes32[] calldata, /* proof */
        MintParams calldata mintparams
    ) external returns (uint256 tokenId, address ipId) {
        uint256 amount = _registerMinting(stage, signature, mintparams);

        for (uint256 i = 0; i < amount; ++i) {
            (tokenId, ipId) = _mintToSelf();

            // Transfer NFT to the recipient
            _transfer(address(this), mintparams.to, tokenId);
        }

        emit PunkNFTMinted(mintparams.to, tokenId, ipId);
    }

    function setRootIpId(address ipId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rootIpId = ipId;
    }

    /// @notice Mints an NFT to the contract itself.
    /// @return tokenId The token ID of the minted NFT.
    /// @return ipId The IP ID of the minted NFT.
    function _mintToSelf() internal returns (uint256 tokenId, address ipId) {
        tokenId = ++totalMintedAmount;
        _safeMint(address(this), tokenId);

        ipId = _registerIp(tokenId);

        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = rootIpId;
        licenseTermsIds[0] = DEFAULT_LICENSE_TERMS_ID;

        // Make the NFT a derivative of the root IP
        _makeDerivative(ipId, parentIpIds, PIL_TEMPLATE, licenseTermsIds, "");
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
}
