// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Story NFT Interface
/// @notice A Story NFT is a soulbound NFT that has an unified token URI for all tokens.
interface IOkxMultiRound {
    // ////////////////////////////////////////////////////////////////////////////
    // //                              Errors                                    //
    // ////////////////////////////////////////////////////////////////////////////
    // /// @notice Invalid whitelist signature.
    error InvalidSignature();

    /// @notice The provided whitelist signature is already used.
    error SignatureAlreadyUsed();

    error ExceedPerAddressLimit();
    error ExceedMaxSupply();
    error NotActive();
    error NonExistStage();
    error ExistStage();
    error InvalidStageMaxSupply();
    error InvalidMaxSupply();
    error ExpiredSignature();
    error ExceedMaxSupplyForStage();

    enum MintType {
        Public,
        Allowlist
    }

    /**
     * @notice The mint details for each stage
     *
     * @param enableSig                If needs server signature.
     * @param limitationForAddress     The mint amountlimitation for each address in a stage.
     * @param maxSupplyForStage        The max supply for a stage.
     * @param startTime                The start time of a stage.
     * @param endTime                  The end time of a stage.
     * //  * @param price                    The mint price in a stage.
     * //  * @param paymentToken             The mint paymentToken in a stage.
     * //  * @param payeeAddress             The payeeAddress in a stage.
     * //  * @param allowListMerkleRoot      The allowListMerkleRoot in a stage.
     * @param stage                    The tag of the stage.
     * @param mintType                 Mint type. e.g.Public,Allowlist,Signd
     */
    struct StageMintInfo {
        bool enableSig; //8bits
        uint8 limitationForAddress; //16bits
        uint32 maxSupplyForStage; //48bits
        uint64 startTime; //112bits
        uint64 endTime; //176bits
        string stage;
        MintType mintType;
    }

    /**
     * @notice The parameter of mint.
     *
     * @param amount     The amount of mint.
     * @param tokenId    Unused.
     * @param nonce      Random number.For server signature, only used in enableSig is true.
     * @param expiry     The expiry of server signature, only used in enableSig is true.
     * @param to         The to address of the mint.
     */
    struct MintParams {
        uint256 amount;
        uint256 tokenId;
        uint256 nonce;
        uint256 expiry;
        address to;
    }

    /// @notice Emitted when the signer is updated.
    /// @param signer The new signer address.
    event SignerUpdated(address signer);

    event StageMintTimeSet(string stage, uint64 startTime, uint64 endTime);
    event StageMintLimitationPerAddressSet(string stage, uint8 mintLimitationPerAddress);
    event StageMaxSupplySet(string stage, uint32 maxSupply);
    event MaxSupplySet(uint32 maxSupply);
    event StageEnableSigSet(string stage, bool enableSig);
    event StageMintInfoSet(StageMintInfo stageMintInfo);

    function mintRecord(address user, string memory stage) external view returns (uint256);

    /// @notice return the total supply of the stage.
    function stageToTotalSupply(string memory stage) external view returns (uint256);

    /// @notice Sets the mint information for a specific stage.
    /// @param stageMintInfo The mint information for the stage.
    function setStageMintInfo(StageMintInfo calldata stageMintInfo) external;

    /// @notice Sets the maximum supply for the NFT collection.
    /// @param newMaxSupply The maximum supply of the NFT collection.
    function setMaxSupply(uint32 newMaxSupply) external;

    /// @notice Sets the mint limitation per address for a specific stage.
    /// @param stage The stage identifier.
    /// @param mintLimitationPerAddress The mint limitation per address for the stage.
    function setStageMintLimitationPerAddress(string calldata stage, uint8 mintLimitationPerAddress) external;

    /// @notice Sets the mint time for a specific stage.
    /// @param stage The stage identifier.
    /// @param startTime The start time of the stage.
    /// @param endTime The end time of the stage.
    function setStageMintTime(string calldata stage, uint64 startTime, uint64 endTime) external;

    /// @notice Sets whether a signature is required for minting in a specific stage.
    /// @param stage The stage identifier.
    /// @param enableSig Boolean indicating whether a signature is required.
    function setStageEnableSig(string calldata stage, bool enableSig) external;

    /// @notice Updates the whitelist signer.
    /// @param signer_ The new whitelist signer address.
    function setSigner(address signer_) external;
}
