// scripts/CustomERC20/0_deploy.js
const { ethers } = require("hardhat");
let scInfo = require("../../scInfo.json");
const fs = require("fs");

async function main() {
    const accounts = await ethers.getSigners();
    const deployer = accounts[2];

    console.log("Deployer address:", deployer.address);

    // Deploy Restrictions
    const contractFactory = await ethers.getContractFactory("CustomERC20", deployer);
    const customERC20 = await contractFactory.deploy();
    console.log("CustomERC20 deployed with address:", customERC20.target);

    console.log("write in scInfo json");
    scInfo.customERC20Address = customERC20.target;

    await fs.writeFileSync("scInfo.json", JSON.stringify(scInfo), "utf-8", (err) => {
        if (err) console.log("Error writing file cause:", err);
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
