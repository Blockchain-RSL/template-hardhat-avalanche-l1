const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LoanAsset Contract", function () {
    let LoanAsset, loanAsset, accounts, issuer, lenders, borrowers;
    let loanAnagInfo, loanParticipantInfo, loanPaymentInfo;
    let ipfsDocumentationLink = "ipfs://your_ipfs_hash_here";

    before(async function () {
        accounts = await ethers.getSigners();
        issuer = accounts[0];
        lenders = [accounts[1]];
        borrowers = [accounts[2]];

        // Conversione stringhe in bytes32
        const name = ethers.encodeBytes32String("Loan Asset");
        const issuanceCountry = ethers.encodeBytes32String("IT");
        const currency = ethers.encodeBytes32String("EUR");

        // Enum mapping (LoanType, InterestRateType)
        const loanType = 0; // BULLET
        const interestRateType = 0; // FIXED

        // Date
        const startDate = Math.floor(Date.now() / 1000);
        const firstRepaymentDate = startDate + 10;
        const maturityDate = firstRepaymentDate + 10;

        loanAnagInfo = {
            name,
            issuanceCountry,
            currency,
            loanType,
            interestRateType,
            startDate,
            maturityDate,
        };

        loanParticipantInfo = {
            lenders: lenders.map((lender) => lender.address),
            lendersShares: [100],
            borrowers: borrowers.map((borrower) => borrower.address),
            borrowersShares: [100],
        };

        loanPaymentInfo = {
            totalAmount: 1000,
            minimumDenomination: 10,
            spreadForBorrower: [100],
            interestRates: [500],
            repaymentsDates: [firstRepaymentDate, maturityDate],
        };

        LoanAsset = await ethers.getContractFactory("LoanAsset");
        loanAsset = await LoanAsset.deploy(loanAnagInfo, loanParticipantInfo, loanPaymentInfo, ipfsDocumentationLink);
        await loanAsset.waitForDeployment();
    });

    it("Should deploy the contract", async function () {
        expect(loanAsset.target).to.not.be.null;
        console.log("Contract deployed at:", loanAsset.target);
    });

    it("Should allow lender to deposit funds", async function () {
        const lender = lenders[0];

        const lenderInfo = await loanAsset.lendersInfo(lender.address);
        const shares = lenderInfo.shares;
        const minDenomination = await loanAsset.MINIMUM_DENOMINATION_PER_SHARE();
        const amountToDeposit = shares * minDenomination;

        await expect(loanAsset.connect(lender).depositFunds({ value: amountToDeposit })).to.changeEtherBalances(
            [lender, loanAsset],
            [-amountToDeposit, amountToDeposit]
        );
    });

    it("Should start the loan", async function () {
        await expect(loanAsset.connect(issuer).setLoanStart()).to.emit(loanAsset, "LoanStartedEvent");
    });

    it("Should process borrower repayment", async function () {
        const borrower = borrowers[0];

        const amountToPay = await loanAsset.calculateNextRepaymentAmount();
        const borrowerRepaymentInfo = await loanAsset.getRepaymentInfo(0);
        const paymentTimestamp = Number(borrowerRepaymentInfo.paymentDate);

        let currentTimestamp = Math.floor(Date.now() / 1000);
        const waitTime = paymentTimestamp - currentTimestamp;

        if (waitTime > 0) {
            console.log(`Waiting for ${waitTime + 2} seconds before repayment...`);
            await new Promise((resolve) => setTimeout(resolve, (waitTime + 2) * 1000));
        }

        await expect(loanAsset.connect(borrower).payRepayment(0, { value: amountToPay })).to.changeEtherBalances(
            [borrower, loanAsset],
            [-amountToPay, amountToPay]
        );
    });

    it("Should mature the loan", async function () {
        await expect(loanAsset.connect(issuer).setLoanMatured()).to.emit(loanAsset, "LoanMaturedEvent");
    });

    it("Should process principal payment", async function () {
        const borrower = borrowers[0];

        const principalAmountToPay = await loanAsset.calculatePrincipalAmount();
        const borrowerPrincipalRepaymentInfo = await loanAsset.getRepaymentInfo(1);
        const paymentPrincipalTimestamp = Number(borrowerPrincipalRepaymentInfo.paymentDate);

        let currentTimestamp = Math.floor(Date.now() / 1000);
        const waitTime = paymentPrincipalTimestamp - currentTimestamp;

        if (waitTime > 0) {
            console.log(`Waiting for ${waitTime + 2} seconds before principal payment...`);
            await new Promise((resolve) => setTimeout(resolve, (waitTime + 2) * 1000));
        }

        await expect(loanAsset.connect(borrower).payPrincipal({ value: principalAmountToPay })).to.changeEtherBalances(
            [borrower, loanAsset],
            [-principalAmountToPay, principalAmountToPay]
        );
    });

    it("Should close the loan", async function () {
        await expect(loanAsset.connect(issuer).setLoanClosed()).to.emit(loanAsset, "LoanClosedEvent");
    });

    it("Should allow lender to withdraw funds", async function () {
        const lender = lenders[0];

        await expect(loanAsset.connect(lender).withdrawFunds()).to.changeEtherBalances([lender, loanAsset]);
    });
});
