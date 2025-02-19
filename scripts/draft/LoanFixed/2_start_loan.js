// scripts/CustomERC20/0_deploy.js
const { ethers } = require("hardhat");
let scInfo = require("../../../scInfoLoan.json");
const fs = require("fs");

async function main() {
    const accounts = await ethers.getSigners();
    const issuer = accounts[0];
    const borrower = accounts[2];

    console.log("issuer address:", borrower.address);

    // get loan address from scInfo
    const loanAssetAddress = scInfo.loanAssetAddress;
    const loanAssetContract = await hre.ethers.getContractAt("LoanAsset", loanAssetAddress);

    console.log("Borrower balance before loan start", await hre.ethers.provider.getBalance(borrower.address));
    console.log("Loan balance before loan start", await hre.ethers.provider.getBalance(loanAssetAddress));
    console.log("Start Loan - START");

    trx = await loanAssetContract.connect(issuer).setLoanStart();
    await trx.wait();

    console.log("Start Loan - END");
    console.log("Loan balance after loan start", await hre.ethers.provider.getBalance(loanAssetAddress));
    console.log("Borrower balance after loan start", await hre.ethers.provider.getBalance(borrower.address));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
