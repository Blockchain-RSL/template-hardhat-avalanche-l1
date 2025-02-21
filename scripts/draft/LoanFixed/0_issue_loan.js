// scripts/CustomERC20/0_deploy.js
const { ethers } = require("hardhat");
let scInfo = require("../../../scInfoLoan.json");
const fs = require("fs");

async function main() {
    const accounts = await ethers.getSigners();
    const issuer = accounts[0];
    const lenders = [accounts[1]];
    const borrowers = [accounts[2]];

    console.log("Issuer address:", issuer.address);

    // Conversione stringhe in bytes32
    const name = ethers.encodeBytes32String("Loan Asset");
    const issuanceCountry = ethers.encodeBytes32String("IT");
    const currency = ethers.encodeBytes32String("EUR");

    // Enum mapping (LoanType, InterestRateType)
    const loanType = 0; // BULLET
    const interestRateType = 0; // FIXED

    // Date
    const startDate = Math.floor(Date.now() / 1000) + 50; // Timestamp current
    const firstRepaymentDate = startDate + 50;
    const maturityDate = firstRepaymentDate + 50;

    // LoanAnagInfo struct
    const loanAnagInfo = {
        name: name,
        issuanceCountry: issuanceCountry,
        currency: currency,
        loanType: loanType,
        interestRateType: interestRateType,
        startDate: startDate,
        maturityDate: maturityDate,
    };

    // LoanParticipantInfo struct
    const loanParticipantInfo = {
        lenders: lenders.map((lender) => lender.address),
        lendersShares: [100],
        borrowers: borrowers.map((borrower) => borrower.address),
        borrowersShares: [100],
    };

    // LoanPaymentInfo struct
    const loanPaymentInfo = {
        totalAmount: 1000, // Total wei amount
        minimumDenomination: 10, // minimum denomination
        spreadForBorrower: [100], // Spread percentage
        interestRates: [500], // IR basis points (5%)
        repaymentsDates: [firstRepaymentDate, maturityDate], // Rate after 10 seconds
    };

    const _ipfsDocumentationLink = "ipfs://your_ipfs_hash_here";

    console.log("Deploying Loan Asset with the following parameters:");
    console.log("LoanAnagInfo:", loanAnagInfo);
    console.log("LoanParticipantInfo:", loanParticipantInfo);
    console.log("LoanPaymentInfo:", loanPaymentInfo);
    console.log("IPFS Documentation Link:", _ipfsDocumentationLink);

    // Deploy contract
    const LoanAsset = await ethers.getContractFactory("LoanAsset");
    const loanAsset = await LoanAsset.deploy(
        loanAnagInfo,
        loanParticipantInfo,
        loanPaymentInfo,
        _ipfsDocumentationLink
    );
    await loanAsset.waitForDeployment();
    console.log("Loan Asset deployed with address:", loanAsset.target);

    console.log("write in scInfo json");
    scInfo.loanAssetAddress = loanAsset.target;

    await fs.writeFileSync("scInfoLoan.json", JSON.stringify(scInfo), "utf-8", (err) => {
        if (err) console.log("Error writing file cause:", err);
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
