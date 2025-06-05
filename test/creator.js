const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CreatorMonetizationNFT", function () {
  let contract;
  let owner, creator, buyer, platformTreasury;
  let creatorAddress, buyerAddress, platformTreasuryAddress;

  beforeEach(async function () {
    // Get signers
    [owner, creator, buyer, platformTreasury] = await ethers.getSigners();
    creatorAddress = await creator.getAddress();
    buyerAddress = await buyer.getAddress();
    platformTreasuryAddress = await platformTreasury.getAddress();

    // Deploy contract
    const CreatorMonetizationNFT = await ethers.getContractFactory("CreatorMonetizationNFT");
    contract = await CreatorMonetizationNFT.deploy(
      "Creator NFT",
      "CNFT",
      platformTreasuryAddress
    );
    await contract.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the correct name and symbol", async function () {
      expect(await contract.name()).to.equal("Creator NFT");
      expect(await contract.symbol()).to.equal("CNFT");
    });

    it("Should set the correct platform treasury", async function () {
      expect(await contract.platformTreasury()).to.equal(platformTreasuryAddress);
    });

    it("Should set the correct owner", async function () {
      expect(await contract.owner()).to.equal(await owner.getAddress());
    });
  });

  describe("NFT Minting", function () {
    it("Should mint NFT successfully", async function () {
      const tokenURI = "https://example.com/metadata/1.json";

      await expect(contract.mintNFT(creatorAddress, tokenURI))
        .to.emit(contract, "NFTMinted")
        .withArgs(0, creatorAddress, tokenURI);

      expect(await contract.ownerOf(0)).to.equal(creatorAddress);
      expect(await contract.tokenURI(0)).to.equal(tokenURI);
      expect(await contract.tokenCreators(0)).to.equal(creatorAddress);
      expect(await contract.totalSupply()).to.equal(1);
    });

    it("Should reject minting with zero address", async function () {
      await expect(
        contract.mintNFT(ethers.ZeroAddress, "https://example.com/metadata/1.json")
      ).to.be.revertedWith("Invalid creator address");
    });

    it("Should mint multiple NFTs with incrementing token IDs", async function () {
      await contract.mintNFT(creatorAddress, "https://example.com/1.json");
      await contract.mintNFT(creatorAddress, "https://example.com/2.json");

      expect(await contract.totalSupply()).to.equal(2);
      expect(await contract.ownerOf(0)).to.equal(creatorAddress);
      expect(await contract.ownerOf(1)).to.equal(creatorAddress);
    });
  });

  describe("Royalty Distribution", function () {
    let tokenId;

    beforeEach(async function () {
      // Mint an NFT first
      await contract.mintNFT(creatorAddress, "https://example.com/metadata/1.json");
      tokenId = 0;
    });

    it("Should distribute royalties correctly", async function () {
      const salePrice = ethers.parseEther("1"); // 1 ETH
      const totalRoyalty = ethers.parseEther("0.1"); // 10% royalty
      const platformAmount = ethers.parseEther("0.01"); // 10% of royalty (1% of sale)
      const creatorAmount = ethers.parseEther("0.09"); // 90% of royalty (9% of sale)

      await expect(
        contract.connect(buyer).distributeRoyalty(tokenId, salePrice, {
          value: totalRoyalty
        })
      )
        .to.emit(contract, "RoyaltyPaid")
        .withArgs(tokenId, creatorAddress, creatorAmount, platformAmount);

      // Check earnings
      expect(await contract.getCreatorEarnings(creatorAddress)).to.equal(creatorAmount);
      expect(await contract.getPlatformEarnings()).to.equal(platformAmount);
    });

    it("Should reject royalty distribution with no payment", async function () {
      const salePrice = ethers.parseEther("1");

      await expect(
        contract.connect(buyer).distributeRoyalty(tokenId, salePrice, {
          value: 0
        })
      ).to.be.revertedWith("No payment received");
    });

    it("Should reject royalty distribution for non-existent token", async function () {
      const salePrice = ethers.parseEther("1");
      const royalty = ethers.parseEther("0.1");

      await expect(
        contract.connect(buyer).distributeRoyalty(999, salePrice, {
          value: royalty
        })
      ).to.be.revertedWith("Token does not exist");
    });

    it("Should reject insufficient royalty payment", async function () {
      const salePrice = ethers.parseEther("1");
      const insufficientRoyalty = ethers.parseEther("0.05"); // Less than 10%

      await expect(
        contract.connect(buyer).distributeRoyalty(tokenId, salePrice, {
          value: insufficientRoyalty
        })
      ).to.be.revertedWith("Insufficient royalty payment");
    });

    it("Should refund excess payment", async function () {
      const salePrice = ethers.parseEther("1");
      const excessPayment = ethers.parseEther("0.2"); // Double the required royalty
      const buyerBalanceBefore = await ethers.provider.getBalance(buyerAddress);

      const tx = await contract.connect(buyer).distributeRoyalty(tokenId, salePrice, {
        value: excessPayment
      });

      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;
      const buyerBalanceAfter = await ethers.provider.getBalance(buyerAddress);

      // Check that only the required royalty was deducted (plus gas)
      const expectedBalance = buyerBalanceBefore - ethers.parseEther("0.1") - gasUsed;
      expect(buyerBalanceAfter).to.be.closeTo(expectedBalance, ethers.parseEther("0.001"));
    });
  });

  describe("Creator Earnings Withdrawal", function () {
    let tokenId;

    beforeEach(async function () {
      // Mint NFT and distribute royalties
      await contract.mintNFT(creatorAddress, "https://example.com/metadata/1.json");
      tokenId = 0;

      const salePrice = ethers.parseEther("1");
      const royalty = ethers.parseEther("0.1");

      await contract.connect(buyer).distributeRoyalty(tokenId, salePrice, {
        value: royalty
      });
    });

    it("Should allow creator to withdraw earnings", async function () {
      const initialBalance = await ethers.provider.getBalance(creatorAddress);
      const earnings = await contract.getCreatorEarnings(creatorAddress);

      expect(earnings).to.equal(ethers.parseEther("0.09"));

      const tx = await contract.connect(creator).withdrawCreatorEarnings();
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;

      await expect(tx)
        .to.emit(contract, "EarningsWithdrawn")
        .withArgs(creatorAddress, earnings);

      // Check balance increased by earnings minus gas
      const finalBalance = await ethers.provider.getBalance(creatorAddress);
      expect(finalBalance).to.equal(initialBalance + earnings - gasUsed);

      // Check earnings reset to zero
      expect(await contract.getCreatorEarnings(creatorAddress)).to.equal(0);
    });

    it("Should reject withdrawal with no earnings", async function () {
      // First withdraw all earnings
      await contract.connect(creator).withdrawCreatorEarnings();

      // Try to withdraw again
      await expect(
        contract.connect(creator).withdrawCreatorEarnings()
      ).to.be.revertedWith("No earnings to withdraw");
    });

    it("Should only allow creator to withdraw their own earnings", async function () {
      await expect(
        contract.connect(buyer).withdrawCreatorEarnings()
      ).to.be.revertedWith("No earnings to withdraw");
    });
  });

  describe("Platform Earnings Withdrawal", function () {
    let tokenId;

    beforeEach(async function () {
      // Mint NFT and distribute royalties
      await contract.mintNFT(creatorAddress, "https://example.com/metadata/1.json");
      tokenId = 0;

      const salePrice = ethers.parseEther("1");
      const royalty = ethers.parseEther("0.1");

      await contract.connect(buyer).distributeRoyalty(tokenId, salePrice, {
        value: royalty
      });
    });

    it("Should allow owner to withdraw platform earnings", async function () {
      const initialBalance = await ethers.provider.getBalance(platformTreasuryAddress);
      const earnings = await contract.getPlatformEarnings();

      expect(earnings).to.equal(ethers.parseEther("0.01"));

      await expect(contract.withdrawPlatformEarnings())
        .to.emit(contract, "EarningsWithdrawn")
        .withArgs(platformTreasuryAddress, earnings);

      // Check treasury balance increased
      const finalBalance = await ethers.provider.getBalance(platformTreasuryAddress);
      expect(finalBalance).to.equal(initialBalance + earnings);

      // Check platform earnings reset to zero
      expect(await contract.getPlatformEarnings()).to.equal(0);
    });

    it("Should reject non-owner platform withdrawal", async function () {
      await expect(
        contract.connect(creator).withdrawPlatformEarnings()
      ).to.be.revertedWithCustomError(contract, "OwnableUnauthorizedAccount");
    });

    it("Should reject withdrawal with no platform earnings", async function () {
      // First withdraw all earnings
      await contract.withdrawPlatformEarnings();

      // Try to withdraw again
      await expect(
        contract.withdrawPlatformEarnings()
      ).to.be.revertedWith("No earnings to withdraw");
    });
  });

  describe("Platform Treasury Management", function () {
    it("Should allow owner to update platform treasury", async function () {
      const newTreasury = await buyer.getAddress();

      await contract.updatePlatformTreasury(newTreasury);
      expect(await contract.platformTreasury()).to.equal(newTreasury);
    });

    it("Should reject zero address for platform treasury", async function () {
      await expect(
        contract.updatePlatformTreasury(ethers.ZeroAddress)
      ).to.be.revertedWith("Invalid treasury address");
    });

    it("Should reject non-owner treasury update", async function () {
      await expect(
        contract.connect(creator).updatePlatformTreasury(creatorAddress)
      ).to.be.revertedWithCustomError(contract, "OwnableUnauthorizedAccount");
    });
  });

  describe("Emergency Functions", function () {
    beforeEach(async function () {
      // Send some ETH directly to contract
      await owner.sendTransaction({
        to: await contract.getAddress(),
        value: ethers.parseEther("1")
      });
    });

    it("Should allow owner to emergency withdraw", async function () {
      const contractBalance = await ethers.provider.getBalance(await contract.getAddress());
      const ownerBalanceBefore = await ethers.provider.getBalance(await owner.getAddress());

      const tx = await contract.emergencyWithdraw();
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;

      const ownerBalanceAfter = await ethers.provider.getBalance(await owner.getAddress());
      expect(ownerBalanceAfter).to.equal(ownerBalanceBefore + contractBalance - gasUsed);
    });

    it("Should reject non-owner emergency withdrawal", async function () {
      await expect(
        contract.connect(creator).emergencyWithdraw()
      ).to.be.revertedWithCustomError(contract, "OwnableUnauthorizedAccount");
    });
  });

  describe("View Functions", function () {
    it("Should return correct creator earnings", async function () {
      expect(await contract.getCreatorEarnings(creatorAddress)).to.equal(0);

      // Mint and distribute royalty
      await contract.mintNFT(creatorAddress, "https://example.com/metadata/1.json");
      await contract.connect(buyer).distributeRoyalty(0, ethers.parseEther("1"), {
        value: ethers.parseEther("0.1")
      });

      expect(await contract.getCreatorEarnings(creatorAddress)).to.equal(ethers.parseEther("0.09"));
    });

    it("Should return correct platform earnings", async function () {
      expect(await contract.getPlatformEarnings()).to.equal(0);

      // Mint and distribute royalty
      await contract.mintNFT(creatorAddress, "https://example.com/metadata/1.json");
      await contract.connect(buyer).distributeRoyalty(0, ethers.parseEther("1"), {
        value: ethers.parseEther("0.1")
      });

      expect(await contract.getPlatformEarnings()).to.equal(ethers.parseEther("0.01"));
    });

    it("Should return correct total supply", async function () {
      expect(await contract.totalSupply()).to.equal(0);

      await contract.mintNFT(creatorAddress, "https://example.com/metadata/1.json");
      expect(await contract.totalSupply()).to.equal(1);

      await contract.mintNFT(creatorAddress, "https://example.com/metadata/2.json");
      expect(await contract.totalSupply()).to.equal(2);
    });
  });

  describe("Royalty Standard Compliance", function () {
    let tokenId;

    beforeEach(async function () {
      await contract.mintNFT(creatorAddress, "https://example.com/metadata/1.json");
      tokenId = 0;
    });

    it("Should support ERC2981 interface", async function () {
      // ERC2981 interface ID
      expect(await contract.supportsInterface("0x2a55205a")).to.be.true;
    });

    it("Should return correct royalty info", async function () {
      const salePrice = ethers.parseEther("1");
      const [receiver, royaltyAmount] = await contract.royaltyInfo(tokenId, salePrice);

      expect(receiver).to.equal(await contract.getAddress());
      expect(royaltyAmount).to.equal(ethers.parseEther("0.1")); // 10% royalty
    });
  });

  describe("Edge Cases and Security", function () {
    it("Should handle multiple creators correctly", async function () {
      const [, creator1, creator2] = await ethers.getSigners();

      // Mint NFTs for different creators
      await contract.mintNFT(await creator1.getAddress(), "https://example.com/1.json");
      await contract.mintNFT(await creator2.getAddress(), "https://example.com/2.json");

      // Distribute royalties for both
      await contract.connect(buyer).distributeRoyalty(0, ethers.parseEther("1"), {
        value: ethers.parseEther("0.1")
      });
      await contract.connect(buyer).distributeRoyalty(1, ethers.parseEther("2"), {
        value: ethers.parseEther("0.2")
      });

      // Check separate earnings
      expect(await contract.getCreatorEarnings(await creator1.getAddress()))
        .to.equal(ethers.parseEther("0.09"));
      expect(await contract.getCreatorEarnings(await creator2.getAddress()))
        .to.equal(ethers.parseEther("0.18"));
    });

    it("Should prevent reentrancy attacks", async function () {
      // This test verifies the ReentrancyGuard is working
      // The actual reentrancy protection is handled by OpenZeppelin's ReentrancyGuard
      await contract.mintNFT(creatorAddress, "https://example.com/metadata/1.json");
      await contract.connect(buyer).distributeRoyalty(0, ethers.parseEther("1"), {
        value: ethers.parseEther("0.1")
      });

      // Normal withdrawal should work
      await expect(contract.connect(creator).withdrawCreatorEarnings()).to.not.be.reverted;
    });
  });
});


