// scripts/deploy.js
async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);

    // Replace this with your platform treasury address, can be deployer's address for testing
    const platformTreasury = deployer.address;

    const CreatorMonetizationNFT = await ethers.getContractFactory("CreatorMonetizationNFT");
    const nftContract = await CreatorMonetizationNFT.deploy("CreatorNFT", "CNFT", platformTreasury);

    await nftContract.deployed();

    console.log("CreatorMonetizationNFT deployed to:", nftContract.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
