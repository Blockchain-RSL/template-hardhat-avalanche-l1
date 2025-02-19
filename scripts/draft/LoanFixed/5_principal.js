// scripts/CustomERC20/0_deploy.js
const { ethers } = require("hardhat");
let scInfo = require("../../../scInfoLoan.json");
const fs = require("fs");

async function main() {
    const accounts = await ethers.getSigners();
    const borrower = accounts[2];

    console.log("borrower address:", borrower.address);

    // get loan address from scInfo
    const loanAssetAddress = scInfo.loanAssetAddress;
    const loanAssetContract = await hre.ethers.getContractAt("LoanAsset", loanAssetAddress);

    console.log("Borrower balance before principal start", await hre.ethers.provider.getBalance(borrower.address));
    console.log("Loan balance before principal start", await hre.ethers.provider.getBalance(loanAssetAddress));
    console.log("Start pay principal - START");

    // get amount to pay
    const principalAmountToPay = await loanAssetContract.connect(borrower).calculatePrincipalAmount();
    console.log("Principal Amount to pay", principalAmountToPay.toString());

    const borrowerPrincipalRepaymentInfo = await loanAssetContract.connect(borrower).getRepaymentInfo(1);
    console.log("Timestamp to wait", borrowerPrincipalRepaymentInfo.paymentDate.toString());

    const paymentPrincipalTimestamp = Number(borrowerPrincipalRepaymentInfo.paymentDate); // Converte BigInt in number

    // get current timestamp
    currentTimestamp = Math.floor(Date.now() / 1000);
    console.log("Current timestamp", currentTimestamp);

    // wait until payment timestamp
    console.log("Timestamp to wait", paymentPrincipalTimestamp - currentTimestamp);

    await new Promise((resolve) => setTimeout(resolve, paymentPrincipalTimestamp - currentTimestamp + 2));

    console.log("start pay principal");
    trx = await loanAssetContract.connect(borrower).payPrincipal({ value: principalAmountToPay });
    await trx.wait();

    console.log("Start pay principal - END");
    console.log("Borrower balance after principal start", await hre.ethers.provider.getBalance(borrower.address));
    console.log("Loan balance after principal start", await hre.ethers.provider.getBalance(loanAssetAddress));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
