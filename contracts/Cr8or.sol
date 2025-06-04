// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Cr8or is Ownable {
    IERC721 public nftContract;

    // tokenId => price in wei
    mapping(uint256 => uint256) public tokenPrices;

    constructor(address _nftAddress) {
        nftContract = IERC721(_nftAddress);
    }

    /// @notice Set price for a token (only owner or creator should do this)
    function setPrice(uint256 tokenId, uint256 price) external {
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not token owner");
        tokenPrices[tokenId] = price;
    }

    /// @notice Buy the NFT
    function buy(uint256 tokenId) external payable {
        uint256 price = tokenPrices[tokenId];
        address seller = nftContract.ownerOf(tokenId);

        require(price > 0, "Token not for sale");
        require(msg.value == price, "Incorrect ETH sent");
        require(seller != msg.sender, "You already own this");

        // Transfer NFT to buyer
        nftContract.transferFrom(seller, msg.sender, tokenId);

        // Forward funds to seller
        payable(seller).transfer(msg.value);

        // Clear price
        tokenPrices[tokenId] = 0;
    }
}
