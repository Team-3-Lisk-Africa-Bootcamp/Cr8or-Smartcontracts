// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./Cr8orAdmin.sol";

/**
 * @title CreatorMonetizationNFT
 * @dev ERC721 contract with built-in royalty splits (10% platform, 90% creator)
 */
contract CreatorMonetizationNFT is
    ERC721,
    Cr8orAdmin,
    ERC721URIStorage,
    ERC721Royalty,
    Ownable,
    ReentrancyGuard
{
    uint256 private _tokenIdCounter;
    mapping(uint256 => uint256) public tokenPrices;

    // Platform fee: 10% of royalty (1000 basis points out of 10000)
    uint96 public constant PLATFORM_FEE_BASIS_POINTS = 1000;
    uint96 public constant CREATOR_FEE_BASIS_POINTS = 9000;
    uint96 public constant TOTAL_ROYALTY_BASIS_POINTS = 1000; // 10% total royalty

    // Platform treasury address
    address public platformTreasury;

    // Mapping from token ID to creator address
    mapping(uint256 => address) public tokenCreators;

    // Mapping to track earnings per creator
    mapping(address => uint256) public creatorEarnings;

    // Platform earnings
    uint256 public platformEarnings;

    // Events
    event NFTMinted(
        uint256 indexed tokenId,
        address indexed creator,
        string tokenURI
    );
    event RoyaltyPaid(
        uint256 indexed tokenId,
        address indexed creator,
        uint256 creatorAmount,
        uint256 platformAmount
    );
    event EarningsWithdrawn(address indexed recipient, uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        address _platformTreasury
    ) ERC721(name, symbol) Ownable(msg.sender) {
        require(_platformTreasury != address(0), "Invalid platform treasury");
        platformTreasury = _platformTreasury;
    }

    function setPrice(uint256 tokenId, uint256 price) internal {
        require(
            ownerOf(tokenId) == msg.sender || isAdmin[msg.sender],
            "Not authorized"
        );
        tokenPrices[tokenId] = price;
    }

    /**
     * @dev Mint NFT with creator royalty setup
     * @param creator The creator of the NFT
     * @param tokenMetadataURI The metadata URI for the NFT
     */
    function mintNFT(
        address creator,
        string memory tokenMetadataURI,
        uint256 price
    ) external returns (uint256) {
        require(creator != address(0), "Invalid creator address");

        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;

        _safeMint(creator, tokenId);
        _setTokenURI(tokenId, tokenMetadataURI);

        // Set up royalty with total 10% (split between platform and creator)
        _setTokenRoyalty(tokenId, address(this), TOTAL_ROYALTY_BASIS_POINTS);

        setPrice(tokenId, price);
        // _setApprovalForAll(msg.sender, address(this), true);

        // Track the creator for this token
        tokenCreators[tokenId] = creator;

        emit NFTMinted(tokenId, creator, tokenMetadataURI);

        return tokenId;
    }

    /**
     * @dev Handle royalty payments and split between creator and platform
     * @param tokenId The token ID that generated royalties
     * @param salePrice The sale price that generated the royalty
     */
    function distributeRoyalty(
        uint256 tokenId,
        uint256 salePrice
    ) external payable nonReentrant {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(msg.value > 0, "No payment received");

        address creator = tokenCreators[tokenId];
        require(creator != address(0), "Creator not found");

        // Calculate total royalty (10% of sale price)
        uint256 totalRoyalty = (salePrice * TOTAL_ROYALTY_BASIS_POINTS) / 10000;
        require(msg.value >= totalRoyalty, "Insufficient royalty payment");

        // Split the royalty: 10% to platform, 90% to creator
        // Platform gets 10% of the total royalty
        uint256 platformAmount = (totalRoyalty * PLATFORM_FEE_BASIS_POINTS) /
            10000;
        // Creator gets the remaining 90%
        uint256 creatorAmount = totalRoyalty - platformAmount;

        // Update earnings
        platformEarnings += platformAmount;
        creatorEarnings[creator] += creatorAmount;

        emit RoyaltyPaid(tokenId, creator, creatorAmount, platformAmount);

        // Refund excess payment
        if (msg.value > totalRoyalty) {
            payable(msg.sender).transfer(msg.value - totalRoyalty);
        }
    }

    /**
     * @dev Allow creators to withdraw their earnings
     */
    function withdrawCreatorEarnings() external nonReentrant {
        uint256 amount = creatorEarnings[msg.sender];
        require(amount > 0, "No earnings to withdraw");

        creatorEarnings[msg.sender] = 0;

        payable(msg.sender).transfer(amount);

        emit EarningsWithdrawn(msg.sender, amount);
    }

    /**
     * @dev Allow platform to withdraw earnings
     */
    function withdrawPlatformEarnings() external onlyOwner nonReentrant {
        uint256 amount = platformEarnings;
        require(amount > 0, "No earnings to withdraw");

        platformEarnings = 0;

        payable(platformTreasury).transfer(amount);

        emit EarningsWithdrawn(platformTreasury, amount);
    }

    /**
     * @dev Update platform treasury address
     * @param _newTreasury New platform treasury address
     */
    function updatePlatformTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Invalid treasury address");
        platformTreasury = _newTreasury;
    }

    /**
     * @dev Get creator earnings for a specific address
     * @param creator The creator address to check
     */
    function getCreatorEarnings(
        address creator
    ) external view returns (uint256) {
        return creatorEarnings[creator];
    }

    /**
     * @dev Get platform earnings
     */
    function getPlatformEarnings() external view returns (uint256) {
        return platformEarnings;
    }

    /**
     * @dev Get total supply of minted NFTs
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721, ERC721URIStorage, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Emergency withdrawal function
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Receive function to accept ETH
    receive() external payable {}
}
