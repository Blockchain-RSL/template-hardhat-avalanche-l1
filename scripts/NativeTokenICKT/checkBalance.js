// scripts/NativeTokenICKT/0_transfer_token.js
const { ethers } = require("hardhat");

async function main() {
    const accounts = await ethers.getSigners();

    for (let i = 0; i < accounts.length; i++) {
        // get balance of receiver
        const balanceAccount = await ethers.provider.getBalance(accounts[i].address);
        console.log(`Balance of ${accounts[i].address}: ${ethers.formatEther(balanceAccount)}`);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
