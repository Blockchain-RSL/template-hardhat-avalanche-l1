// scripts/CustomERC20/0_deploy.js
const { ethers } = require("hardhat");
let scInfo = require("../../../scInfoLoan.json");
const fs = require("fs");

async function main() {
    const accounts = await ethers.getSigners();
    const lender = accounts[1];

    // get loan address from scInfo
    const loanAssetAddress = scInfo.loanAssetAddress;
    console.log("loanAssetAddress", loanAssetAddress);

    // call function depositFunds of LoanAsset
    const loanAssetContract = await hre.ethers.getContractAt("LoanAsset", loanAssetAddress);

    // deposit funds to LoanAsset
    console.log("Balance lender before", await hre.ethers.provider.getBalance(lender));

    // get how much funds lender has to deposit
    const lenderInfo = await loanAssetContract.lendersInfo(lender.address);
    const shares = lenderInfo.shares;

    // get minimum denomination
    const minDenomination = await loanAssetContract.MINIMUM_DENOMINATION_PER_SHARE();

    // calculate amount to deposit
    const amountToDeposit = shares * minDenomination;

    console.log("Amount to withdraw", amountToDeposit);

    console.log("Balance SC before", await hre.ethers.provider.getBalance(loanAssetAddress));

    // PAYABLE FUNCTION
    trx = await loanAssetContract.connect(lender).withdrawFunds();
    await trx.wait();

    //console.log("Balance lender after", await loanAssetContract.balanceOf(lender.address));
    console.log("Balance SC after", await hre.ethers.provider.getBalance(loanAssetAddress));
    console.log("Balance lender after", await hre.ethers.provider.getBalance(lender));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
