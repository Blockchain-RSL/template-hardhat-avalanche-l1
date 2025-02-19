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

    console.log("Borrower balance before repayment start", await hre.ethers.provider.getBalance(borrower.address));
    console.log("Loan balance before repayment start", await hre.ethers.provider.getBalance(loanAssetAddress));
    console.log("Start pay repayment - START");

    // get amount to pay
    const amountToPay = await loanAssetContract.connect(borrower).calculateNextRepaymentAmount();
    console.log("Amount to pay", amountToPay.toString());

    const borrowerRepaymentInfo = await loanAssetContract.connect(borrower).getRepaymentInfo(0);
    console.log("Timestamp to wait", borrowerRepaymentInfo.paymentDate.toString());

    const paymentTimestamp = Number(borrowerRepaymentInfo.paymentDate); // Converte BigInt in number

    // get current timestamp
    let currentTimestamp = Math.floor(Date.now() / 1000);
    console.log("Current timestamp", currentTimestamp);

    // wait until payment timestamp
    console.log("Timestamp to wait", paymentTimestamp - currentTimestamp);

    await new Promise((resolve) => setTimeout(resolve, paymentTimestamp - currentTimestamp + 2));

    console.log("start pay repayment");
    trx = await loanAssetContract.connect(borrower).payRepayment(0, { value: amountToPay });
    await trx.wait();

    console.log("Start pay repayment - END");
    console.log("Borrower balance after repayment start", await hre.ethers.provider.getBalance(borrower.address));
    console.log("Loan balance after repayment start", await hre.ethers.provider.getBalance(loanAssetAddress));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
