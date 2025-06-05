// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./CreatorMonetizationNFT.sol"; // Adjust path as needed
import "@openzeppelin/contracts/access/Ownable.sol";

contract Cr8or is Ownable {
    CreatorMonetizationNFT public nftContract;

    // tokenId => price in wei
    mapping(uint256 => uint256) public tokenPrices;

    constructor(address _nftAddress) {
        nftContract = CreatorMonetizationNFT(_nftAddress);
    }

    /// @notice Set price for a token (only owner/creator should do this)
    function setPrice(uint256 tokenId, uint256 price) external {
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not token owner");
        tokenPrices[tokenId] = price;
    }

    /// @notice Buy the NFT and pay royalties
    function buy(uint256 tokenId) external payable {
        uint256 price = tokenPrices[tokenId];
        address seller = nftContract.ownerOf(tokenId);

        require(price > 0, "Token not for sale");
        require(msg.value == price, "Incorrect ETH sent");
        require(seller != msg.sender, "You already own this");

        // Calculate royalty
        (address royaltyReceiver, uint256 royaltyAmount) = nftContract.royaltyInfo(tokenId, price);

        require(msg.value >= royaltyAmount, "Insufficient royalty amount");

        // Pay royalty to contract (contract will split internally)
        nftContract.distributeRoyalty{value: royaltyAmount}(tokenId, price);

        // Pay seller the rest
        uint256 sellerAmount = msg.value - royaltyAmount;
        payable(seller).transfer(sellerAmount);

        // Transfer NFT to buyer
        nftContract.transferFrom(seller, msg.sender, tokenId);

        // Clear price
        tokenPrices[tokenId] = 0;
    }
}
