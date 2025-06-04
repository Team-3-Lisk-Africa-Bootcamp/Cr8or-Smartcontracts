// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Cr8orNFT is ERC721URIStorage {
    uint256 public tokenCounter;

    constructor() ERC721("Cr8or", "CR8") {
        tokenCounter = 0;
    }

    function mint(address to, string memory tokenURI) public returns (uint256) {
        uint256 tokenId = tokenCounter;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        tokenCounter++;
        return tokenId;
    }
}
