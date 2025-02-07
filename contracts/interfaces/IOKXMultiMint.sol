// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Story NFT Interface
/// @notice A Story NFT is a soulbound NFT that has an unified token URI for all tokens.
interface IOKXMultiMint {
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
    error InvalidPayeeAddress();
    error InvalidTime();
    error NotWhitelisted();

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
     * @param price                    The mint price in a stage.
     * @param paymentToken             The mint paymentToken in a stage.
     * @param payeeAddress             The payeeAddress in a stage.
     * @param allowListMerkleRoot      The allowListMerkleRoot in a stage.
     * @param stage                    The tag of the stage.
     * @param mintType                 Mint type. e.g.Public,Allowlist,Signd
     */
    struct StageMintInfo {
        bool enableSig; //8bits
        uint8 limitationForAddress; //16bits
        uint32 maxSupplyForStage; //48bits
        uint64 startTime; //112bits
        uint64 endTime; //176bits
        uint256 price; //240bits
        address paymentToken;
        address payeeAddress;
        bytes32 allowListMerkleRoot;
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

    //////////////////////////////////////////////////////////////////////////////////
    //                               WRITE FUNCTIONS                                //
    //////////////////////////////////////////////////////////////////////////////////

    /// @notice Check if the minting action of a address is eligible.
    /// @param stage The stage name.
    /// @param proof The proof of the minting action.
    ///     signature The signature of the minting action. (not used)
    /// @param mintparams The minting parameters.
    function eligibleCheckingAndRegister(
        string calldata stage,
        bytes32[] calldata proof,
        bytes calldata signature,
        MintParams calldata mintparams
    ) external returns (uint256 amount);

    /// @notice Configure or update the maximum number of nfts that can be minted.
    /// @param newMaxSupply The new maximum number of nfts that can be minted.
    function setMaxSupply(uint256 newMaxSupply) external;

    /// @notice Updates the whitelist signer.
    /// @param signer_ The new whitelist signer address.
    function setSigner(address signer_) external;

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
    function setStagePayment(string calldata stage, address payeeAddress, address paymentToken, uint256 price)
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
    ///     If the address has not been configured, then it is an add function to configure the address.
    /// @param signer Signer address.
    /// @param status Effective status.
    function setActiveSigner(address signer, bool status) external;

    /// @notice Set whether to restrict transfer, if configured to true, transfer is not allowed.
    ///     Otherwise, transfer is allowed.
    /// @param isTransferRestricted_ Whether to restrict transfer.
    /// @param startTime Start time.
    /// @param endTime End time.
    function setTransferRestricted(bool isTransferRestricted_, uint64 startTime, uint64 endTime) external;

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

    /// @notice Query the maximum number of total mints
    function maxSupply() external view returns (uint256);
}
