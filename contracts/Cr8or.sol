// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./CreatorMonetizationNFT.sol"; 
import "./Cr8orAdmin.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Cr8or is Ownable, CreatorMonetizationNFT, Cr8orAdmin {
    // tokenId => price in wei
    mapping(uint256 => uint256) public tokenPrices;

    constructor(
        string memory name,
        string memory symbol
    )
        CreatorMonetizationNFT(
            name,
            symbol,
            0x8a371e00cd51E2BE005B86EF73C5Ee9Ef6d23FeB
        )
        Cr8orAdmin() // initialize admin constructor
    {}

    /// @notice Set price for a token (only owner/creator should do this)
    function setPrice(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender || isAdmin[msg.sender], "Not authorized");
        tokenPrices[tokenId] = price;
    }

    /// @notice Buy the NFT and pay royalties
    function buy(uint256 tokenId) external payable {
        uint256 price = tokenPrices[tokenId];
        address seller = ownerOf(tokenId);

        require(price > 0, "Token not for sale");
        require(msg.value == price, "Incorrect ETH sent");
        require(seller != msg.sender, "You already own this");

        // Calculate royalty
        (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(tokenId, price);

        require(msg.value >= royaltyAmount, "Insufficient royalty amount");

        // Pay royalty to the royalty receiver
        payable(royaltyReceiver).transfer(royaltyAmount);

        // Pay seller the rest
        uint256 sellerAmount = msg.value - royaltyAmount;
        payable(seller).transfer(sellerAmount);

        // Transfer NFT to buyer
        transferFrom(seller, msg.sender, tokenId);

        // Clear price
        tokenPrices[tokenId] = 0;
    }

    // Override to support interface from CreatorMonetizationNFT
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(CreatorMonetizationNFT) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
