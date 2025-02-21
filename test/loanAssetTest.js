const { expect } = require("chai");
const { ethers } = require("hardhat");
const { extendProvider } = require("hardhat/config");

describe("LoanAsset Contract Test: Ammortatized Fixed 1 lender and 1 borrower", function () {
    let issuer, lender, borrower, faucet;

    before(async function () {
        [issuer, lender, borrower, faucet] = await ethers.getSigners();
        this.lenders = [lender];
        this.borrowers = [borrower];

        const name = ethers.encodeBytes32String("Loan Asset");
        const issuanceCountry = ethers.encodeBytes32String("IT");
        const currency = ethers.encodeBytes32String("EUR");

        // Enum mapping (LoanType, InterestRateType)
        const loanType = 1; // AMMORTIZED
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
            totalAmount: ethers.parseEther("0.01"),
            minimumDenomination: ethers.parseEther("0.0001"),
            spreadForBorrower: [100],
            interestRates: [500],
            repaymentsDates: [this.firstRepaymentDate, maturityDate],
        };
        let blocktimestamp = await ethers.provider.getBlock("latest").then((block) => block.timestamp);
        console.log("blocktimestamp", blocktimestamp);
        console.log("startDate", startDate);
        console.log("maturityDate", maturityDate);
        console.log(blocktimestamp >= startDate);
        console.log(blocktimestamp >= maturityDate);

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
            // expect(await this.loanAsset.ISSUER()).to.equal(issuer.address);
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
                    minimumDenomination * BigInt(borrowerShare)
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
            this.amountToDeposit = BigInt(loanParticipantInfo.lendersShares[0]) * loanPaymentInfo.minimumDenomination;
            let wrongAmount = this.amountToDeposit + BigInt(1);
            await expect(this.loanAsset.connect(lender).depositFunds({ value: wrongAmount }))
                .to.be.revertedWithCustomError(this.loanAsset, "InvalidAmountToFundError")
                .withArgs("Invalid Deposit amount.", this.amountToDeposit, wrongAmount);
        });

        it("Shouldn't allow to deposit to a not enabled lender", async function () {
            expect(this.loanAsset.connect(faucet).depositFunds({ value: this.amountToDeposit }))
                .to.be.revertedWithCustomError(this.loanAsset, "InvalidValueLenderStatusError")
                .withArgs("Only a enabled lender can perform this action.", 0, 1);
        });

        it("When lender deposit funds contract should emit FundsDepositedEvent", async function () {
            expect(await this.loanAsset.connect(lender).depositFunds({ value: this.amountToDeposit }))
                .to.emit(this.loanAsset, "FundsDepositedEvent")
                .withArgs(lender.address, this.amountToDeposit);
        });

        it("Should the contract balance is updated", async function () {
            await new Promise((resolve) => setTimeout(resolve, 2 * 1000)); // TODO capire perchè c'è necessario il timeout
            let contractBalance = await ethers.provider.getBalance(this.loanAsset);
            expect(contractBalance).to.equal(this.amountToDeposit);
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
            await new Promise((resolve) => setTimeout(resolve, 2 * 1000)); // TODO capire perchè c'è necessario il timeout
            expect(await this.loanAsset.currentLoanStatus()).to.equal(1); // 1 --> LIVE
        });

        it("Should the borrower balance is updated", async function () {
            this.amountToTransferToBorrower =
                BigInt(loanParticipantInfo.lendersShares[0]) * loanPaymentInfo.minimumDenomination;
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
        it("Shouldn't allow borrower to pay before the repayment date", async function () {
            let outstandingBorrower =
                BigInt(loanParticipantInfo.borrowersShares[0]) * loanPaymentInfo.minimumDenomination;
            let interestMatured = (outstandingBorrower * BigInt(500 + 100)) / BigInt(10000);
            this.amountToPay = outstandingBorrower / BigInt(2) + interestMatured;
            expect(
                this.loanAsset.connect(borrower).payRepayment(0, { value: this.amountToPay })
            ).to.be.revertedWithCustomError(this.loanAsset, "InvalidDateError");
        });

        it("Shouldn't allow borrower to pay wrong amount", async function () {
            const paymentTimestamp = Number(this.firstRepaymentDate);
            let currentTimestamp = Math.floor(Date.now() / 1000);
            this.waitTime = paymentTimestamp - currentTimestamp;

            if (this.waitTime > 0) {
                console.log(`Waiting for ${this.waitTime + 5} seconds before repayment...`);
                await new Promise((resolve) => setTimeout(resolve, (this.waitTime + 2) * 1000));
            }
            // increment block in avalanche block are created only if there are transactions
            await faucet.sendTransaction({
                to: issuer.address,
                value: ethers.parseEther("0.00001"),
            });

            expect(
                this.loanAsset.connect(borrower).payRepayment(0, { value: this.amountToPay + ethers.parseEther("1") })
            ).to.be.revertedWithCustomError(this.loanAsset, "InvalidValueError");
        });

        it("Shouldn't allow not enabled borrower to pay", async function () {
            await expect(this.loanAsset.connect(faucet).payRepayment(0, { value: this.amountToPay }))
                .to.be.revertedWithCustomError(this.loanAsset, "InvalidValueBorrowerStatusError")
                .withArgs("Invalid borrower status.", 0, 2);
        });

        it("Shouldn't allow borrower to pay wrong repayment index", async function () {
            await expect(this.loanAsset.connect(borrower).payRepayment(2, { value: this.amountToPay }))
                .to.be.revertedWithCustomError(this.loanAsset, "InvalidValueRepaymentIndexError")
                .withArgs("Invalid repayment number.", 2, 2);
        });

        it("When borrower repay first rapayment should emit RepaymentPaidEvent", async function () {
            await expect(this.loanAsset.connect(borrower).payRepayment(0, { value: this.amountToPay }))
                .to.emit(this.loanAsset, "RepaymentPaidEvent")
                .withArgs(borrower.address, this.amountToPay, 0);
        });

        it("Shouldn't allow borrower to pay the same repayment again", async function () {
            await expect(this.loanAsset.connect(borrower).payRepayment(0, { value: this.amountToPay }))
                .to.be.revertedWithCustomError(this.loanAsset, "InvalidRepaymentStatusError")
                .withArgs("Repayment is not in status unpaid.", borrower.address, 2, 1);
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
