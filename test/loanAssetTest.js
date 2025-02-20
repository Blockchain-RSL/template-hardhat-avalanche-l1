const { expect } = require("chai");
const { ethers } = require("hardhat");
const { extendProvider } = require("hardhat/config");

describe("LoanAsset Contract Test: 1 lender and 1 borrower", function () {
    let issuer, lender, borrower, faucet;

    before(async function () {
        [issuer, lender, borrower, faucet] = await ethers.getSigners();
        this.lenders = [lender];
        this.borrowers = [borrower];

        const name = ethers.encodeBytes32String("Loan Asset");
        const issuanceCountry = ethers.encodeBytes32String("IT");
        const currency = ethers.encodeBytes32String("EUR");

        // Enum mapping (LoanType, InterestRateType)
        const loanType = 0; // BULLET
        const interestRateType = 0; // FIXED

        // Date
        const startDate = Math.floor(Date.now() / 1000);
        this.firstRepaymentDate = startDate + 10;
        const maturityDate = this.firstRepaymentDate + 10;

        this.ipfsDocumentationLink = "ipfs://your_ipfs_hash_here";

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
            lenders: this.lenders.map((lender) => lender.address),
            lendersShares: [100],
            borrowers: this.borrowers.map((borrower) => borrower.address),
            borrowersShares: [100],
        };

        loanPaymentInfo = {
            totalAmount: 1000,
            minimumDenomination: 10,
            spreadForBorrower: [100],
            interestRates: [500],
            repaymentsDates: [this.firstRepaymentDate, maturityDate],
        };

        const LoanAsset = await ethers.getContractFactory("LoanAsset");
        this.loanAsset = await LoanAsset.deploy(
            loanAnagInfo,
            loanParticipantInfo,
            loanPaymentInfo,
            this.ipfsDocumentationLink
        );
    });

    describe("Deploy contract loan asset", function () {
        it("Should the contract has a proper address", async function () {
            expect(this.loanAsset.target).to.properAddress;
        });

        it("Should the contract has right loan data", async function () {
            // Check loan info
            expect(await this.loanAsset.ISSUER()).to.equal(issuer.address);
            expect(await this.loanAsset.NAME()).to.equal(loanAnagInfo.name);
            expect(await this.loanAsset.ISSUANCE_COUNTRY()).to.equal(loanAnagInfo.issuanceCountry);
            expect(await this.loanAsset.CURRENCY()).to.equal(loanAnagInfo.currency);
            expect(await this.loanAsset.LOAN_TYPE()).to.equal(loanAnagInfo.loanType);
            expect(await this.loanAsset.INTEREST_RATE_TYPE()).to.equal(loanAnagInfo.interestRateType);
            expect(await this.loanAsset.START_DATE()).to.equal(loanAnagInfo.startDate);
            expect(await this.loanAsset.MATURITY_DATE()).to.equal(loanAnagInfo.maturityDate);
            expect(await this.loanAsset.TOTAL_AMOUNT()).to.equal(loanPaymentInfo.totalAmount);
            expect(await this.loanAsset.MINIMUM_DENOMINATION_PER_SHARE()).to.equal(loanPaymentInfo.minimumDenomination);
            expect(await this.loanAsset.IPFS_DOCUMENTATION_LINK()).to.equal(this.ipfsDocumentationLink);
            expect(await this.loanAsset.currentLoanStatus()).to.equal(0); // 0 --> PRELIMINARY
            expect(await this.loanAsset.TOTAL_REPAYMENT_NUMBER()).to.equal(
                BigInt(loanPaymentInfo.repaymentsDates.length)
            );

            // check repayments dates
            for (let i = 0; i < loanPaymentInfo.repaymentsDates.length; i++) {
                const repaymentDate = await this.loanAsset.REPAYMENTS_DATES(i);
                expect(repaymentDate).to.equal(loanPaymentInfo.repaymentsDates[i]);
            }

            // Check lenders info
            for (let i = 0; i < this.lenders.length; i++) {
                const lenderInfo = await this.loanAsset.lendersInfo(this.lenders[i].address);
                expect(lenderInfo.shares).to.equal(loanParticipantInfo.lendersShares[i]);
                expect(lenderInfo.status).to.equal(1); // 1 --> ENABLED
            }

            // Check borrowers info
            for (let i = 0; i < this.borrowers.length; i++) {
                let borrowerAddress = this.borrowers[i].address;

                const borrowerInfo = await this.loanAsset.borrowersInfo(borrowerAddress);
                const borrowerOutstandingInfo = await this.loanAsset.borrowersOutstandingPrincipals(borrowerAddress);

                const borrowerShare = loanParticipantInfo.borrowersShares[i];
                const minimumDenomination = loanPaymentInfo.minimumDenomination;

                expect(borrowerInfo.shares).to.equal(borrowerShare);
                expect(borrowerInfo.status).to.equal(2); // 1 --> ENABLED
                expect(borrowerInfo.spread).to.equal(loanPaymentInfo.spreadForBorrower[i]);
                expect(borrowerOutstandingInfo.outstandingPrincipalAmount).to.equal(
                    minimumDenomination * borrowerShare
                );
                expect(borrowerOutstandingInfo.nextRepaymentIndex).to.equal(1);
                expect(borrowerOutstandingInfo.anticipatedRepaymentAmount).to.equal(0);
                // check repayment info
                for (let j = 0; j < loanPaymentInfo.repaymentsDates.length; j++) {
                    const borrowerRepaymentInfo = await this.loanAsset.borrowersRepayments(borrowerAddress, j);

                    expect(borrowerRepaymentInfo.paymentDate).to.equal(loanPaymentInfo.repaymentsDates[j]);
                    expect(borrowerRepaymentInfo.interestRate).to.equal(loanPaymentInfo.interestRates[0]);
                    expect(borrowerRepaymentInfo.status).to.equal(1); // 1 --> UNPAID
                }
            }
        });
    });
    describe("Lender deposits funds in the loan asset", function () {
        it("Shouldn't allow to deposit wrong amount", async function () {
            this.amountToDeposit = loanParticipantInfo.lendersShares[0] * loanPaymentInfo.minimumDenomination;
            let wrongAmount = this.amountToDeposit + 1;
            await expect(this.loanAsset.connect(lender).depositFunds({ value: wrongAmount }))
                .to.be.revertedWithCustomError(this.loanAsset, "InvalidAmountToFundError")
                .withArgs("Invalid Deposit amount.", this.amountToDeposit, wrongAmount);
        });

        it("Shouldn't allow to deposit to a not enabled lender", async function () {
            await expect(this.loanAsset.connect(faucet).depositFunds({ value: this.amountToDeposit }))
                .to.be.revertedWithCustomError(this.loanAsset, "InvalidValueLenderStatusError")
                .withArgs("Only a enabled lender can perform this action.", 0, 1);
        });

        it("When lender deposit funds contract should emit FundsDepositedEvent", async function () {
            expect(await this.loanAsset.connect(lender).depositFunds({ value: this.amountToDeposit }))
                .to.emit(this.loanAsset, "FundsDepositedEvent")
                .withArgs(lender.address, this.amountToDeposit);
        });

        it("Should the contract balance is updated", async function () {
            expect(await ethers.provider.getBalance(this.loanAsset)).to.equal(this.amountToDeposit);
        });

        it("Shouldn't allow a lender to deposit funds again", async function () {
            await expect(this.loanAsset.connect(lender).depositFunds({ value: this.amountToDeposit }))
                .to.be.revertedWithCustomError(this.loanAsset, "InvalidValueLenderStatusError")
                .withArgs("Only a enabled lender can perform this action.", 2, 1);
        });
    });

    describe("Issuer starts the loan", function () {
        it("Should emit LoanStartedEvent", async function () {
            // get borrower balance before loan start
            this.balanceBorrower = await ethers.provider.getBalance(borrower.address);
            expect(await this.loanAsset.connect(issuer).setLoanStart()).to.emit(this.loanAsset, "LoanStartedEvent");
        });

        it("Should the contract status is updated", async function () {
            expect(await this.loanAsset.currentLoanStatus()).to.equal(1); // 1 --> LIVE
        });

        it("Should the borrower balance is updated", async function () {
            this.amountToTransferToBorrower =
                loanParticipantInfo.lendersShares[0] * loanPaymentInfo.minimumDenomination;
            expect(await ethers.provider.getBalance(borrower.address)).to.equal(
                this.balanceBorrower + BigInt(this.amountToTransferToBorrower)
            );
        });

        it("Should the contract balance is updated", async function () {
            expect(await ethers.provider.getBalance(this.loanAsset)).to.equal(0);
        });

        it("Shouldn't allow to start the loan again", async function () {
            await expect(this.loanAsset.connect(issuer).setLoanStart())
                .to.be.revertedWithCustomError(this.loanAsset, "InvalidValueLoanStatusError")
                .withArgs("Invalid loan status.", 1, 0);
        });
    });

    describe("Borrower pays the first repayment", function () {
        it("Shouldn't allow to pay wrong amount", async function () {
            //TODO fix this, 'InvalidValueError("Incorrect repayment amount sent.")'
            let outstandingBorrower = loanParticipantInfo.borrowersShares[0] * loanPaymentInfo.minimumDenomination;
            let interestMatured = outstandingBorrower * (0.05 + 0.01);
            let amountToPay = outstandingBorrower / 2 + interestMatured;
            console.log(
                "calculateNextRepaymentAmount",
                await this.loanAsset.connect(borrower).calculateNextRepaymentAmount()
            );

            console.log("outstandingBorrower", outstandingBorrower);
            console.log("interestMatured", interestMatured);
            console.log("amountToPay", amountToPay);
            const paymentTimestamp = Number(this.firstRepaymentDate);

            let currentTimestamp = Math.floor(Date.now() / 1000);
            const waitTime = paymentTimestamp - currentTimestamp;

            if (waitTime > 0) {
                console.log(`Waiting for ${waitTime + 2} seconds before repayment...`);
                await new Promise((resolve) => setTimeout(resolve, (waitTime + 2) * 1000));
            }
            await expect(this.loanAsset.connect(borrower).payRepayment(0, { value: amountToPay }))
                .to.emit(this.loanAsset, "RepaymentPaidEvent")
                .withArgs(borrower.address, 0, amountToPay);
        });
    });

    // it("Should start the loan", async function () {
    //     await expect(loanAsset.connect(issuer).setLoanStart()).to.emit(loanAsset, "LoanStartedEvent");
    // });

    // it("Should process borrower repayment", async function () {
    //     const borrower = borrowers[0];

    //     const amountToPay = await loanAsset.calculateNextRepaymentAmount();
    //     const borrowerRepaymentInfo = await loanAsset.getRepaymentInfo(0);
    //     const paymentTimestamp = Number(borrowerRepaymentInfo.paymentDate);

    //     let currentTimestamp = Math.floor(Date.now() / 1000);
    //     const waitTime = paymentTimestamp - currentTimestamp;

    //     if (waitTime > 0) {
    //         console.log(`Waiting for ${waitTime + 2} seconds before repayment...`);
    //         await new Promise((resolve) => setTimeout(resolve, (waitTime + 2) * 1000));
    //     }

    //     await expect(loanAsset.connect(borrower).payRepayment(0, { value: amountToPay })).to.changeEtherBalances(
    //         [borrower, loanAsset],
    //         [-amountToPay, amountToPay]
    //     );
    // });

    // it("Should mature the loan", async function () {
    //     await expect(loanAsset.connect(issuer).setLoanMatured()).to.emit(loanAsset, "LoanMaturedEvent");
    // });

    // it("Should process principal payment", async function () {
    //     const borrower = borrowers[0];

    //     const principalAmountToPay = await loanAsset.calculatePrincipalAmount();
    //     const borrowerPrincipalRepaymentInfo = await loanAsset.getRepaymentInfo(1);
    //     const paymentPrincipalTimestamp = Number(borrowerPrincipalRepaymentInfo.paymentDate);

    //     let currentTimestamp = Math.floor(Date.now() / 1000);
    //     const waitTime = paymentPrincipalTimestamp - currentTimestamp;

    //     if (waitTime > 0) {
    //         console.log(`Waiting for ${waitTime + 2} seconds before principal payment...`);
    //         await new Promise((resolve) => setTimeout(resolve, (waitTime + 2) * 1000));
    //     }

    //     await expect(loanAsset.connect(borrower).payPrincipal({ value: principalAmountToPay })).to.changeEtherBalances(
    //         [borrower, loanAsset],
    //         [-principalAmountToPay, principalAmountToPay]
    //     );
    // });

    // it("Should close the loan", async function () {
    //     await expect(loanAsset.connect(issuer).setLoanClosed()).to.emit(loanAsset, "LoanClosedEvent");
    // });

    // it("Should allow lender to withdraw funds", async function () {
    //     const lender = lenders[0];

    //     await expect(loanAsset.connect(lender).withdrawFunds()).to.changeEtherBalances([lender, loanAsset]);
    // });
});
