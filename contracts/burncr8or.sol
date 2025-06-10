// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";


mapping(uint256 => uint256) public tokenPrices;

// Mapping to track if token is for sale
mapping(uint256 => bool) public tokenForSale;

// Additional events to add:
event TokenPriceUpdated(
    uint256 indexed tokenId,
    address indexed owner,
    uint256 newPrice,
    bool forSale
);

event TokenBurned(
    uint256 indexed tokenId,
    address indexed owner
);

// BURN FUNCTIONS

/**
 * @dev Burn a token (only owner can burn their own token)
 * @param tokenId The token ID to burn
 */
function burnToken(uint256 tokenId) external {
    require(_ownerOf(tokenId) != address(0), "Token does not exist");
    require(ownerOf(tokenId) == msg.sender, "Only owner can burn token");

    // Remove from sale if it was for sale
    if (tokenForSale[tokenId]) {
        tokenPrices[tokenId] = 0;
        tokenForSale[tokenId] = false;
    }

    // Clear royalty info
    _resetTokenRoyalty(tokenId);

    // Clear creator mapping
    delete tokenCreators[tokenId];

    // Burn the token
    _burn(tokenId);

    emit TokenBurned(tokenId, msg.sender);
}

/**
 * @dev Alternative burn function using ERC721Burnable standard
 * @param tokenId The token ID to burn
 */
function burn(uint256 tokenId) public override {
    require(_ownerOf(tokenId) != address(0), "Token does not exist");
    require(_isAuthorized(ownerOf(tokenId), msg.sender, tokenId), "Not authorized to burn");

    // Remove from sale if it was for sale
    if (tokenForSale[tokenId]) {
        tokenPrices[tokenId] = 0;
        tokenForSale[tokenId] = false;
    }

    // Clear royalty info
    _resetTokenRoyalty(tokenId);

    // Clear creator mapping
    delete tokenCreators[tokenId];

    // Call parent burn function
    super.burn(tokenId);

    emit TokenBurned(tokenId, ownerOf(tokenId));
}

// PRICE UPDATE FUNCTIONS

/**
 * @dev Set price for a token and mark it for sale
 * @param tokenId The token ID to set price for
 * @param price The price in wei (set to 0 to remove from sale)
 */
function setTokenPrice(uint256 tokenId, uint256 price) external {
    require(_ownerOf(tokenId) != address(0), "Token does not exist");
    require(ownerOf(tokenId) == msg.sender, "Only owner can set price");

    tokenPrices[tokenId] = price;
    tokenForSale[tokenId] = price > 0;

    emit TokenPriceUpdated(tokenId, msg.sender, price, price > 0);
}

/**
 * @dev Update price for a token that's already for sale
 * @param tokenId The token ID to update price for
 * @param newPrice The new price in wei
 */
function updateTokenPrice(uint256 tokenId, uint256 newPrice) external {
    require(_ownerOf(tokenId) != address(0), "Token does not exist");
    require(ownerOf(tokenId) == msg.sender, "Only owner can update price");
    require(newPrice > 0, "Price must be greater than 0");

    tokenPrices[tokenId] = newPrice;
    tokenForSale[tokenId] = true;

    emit TokenPriceUpdated(tokenId, msg.sender, newPrice, true);
}

/**
 * @dev Remove token from sale
 * @param tokenId The token ID to remove from sale
 */
function removeFromSale(uint256 tokenId) external {
    require(_ownerOf(tokenId) != address(0), "Token does not exist");
    require(ownerOf(tokenId) == msg.sender, "Only owner can remove from sale");

    tokenPrices[tokenId] = 0;
    tokenForSale[tokenId] = false;

    emit TokenPriceUpdated(tokenId, msg.sender, 0, false);
}

// HELPER FUNCTIONS

/**
 * @dev Get token price and sale status
 * @param tokenId The token ID to check
 */
function getTokenPrice(uint256 tokenId) external view returns (uint256 price, bool forSale) {
    require(_ownerOf(tokenId) != address(0), "Token does not exist");
    return (tokenPrices[tokenId], tokenForSale[tokenId]);
}

/**
 * @dev Check if a token is for sale
 * @param tokenId The token ID to check
 */
function isTokenForSale(uint256 tokenId) external view returns (bool) {
    require(_ownerOf(tokenId) != address(0), "Token does not exist");
    return tokenForSale[tokenId];
}