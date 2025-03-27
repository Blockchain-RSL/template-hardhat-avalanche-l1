const { expect } = require("chai");
const { ethers } = require("hardhat");
const { extendProvider, extendConfig } = require("hardhat/config");

describe("LoanAssetFungible Contract Test: Bullet Fixed 1 Borrower 2 Investors", function () {
    let owner, borrower, investor1, investor2;

    before(async function () {
        [owner, borrower, investor1, investor2] = await ethers.getSigners();

        // init payment token
        const paymentTokenFactory = await ethers.getContractFactory("CustomERC20", owner);
        this.paymentToken = await paymentTokenFactory.deploy();

        expect(this.paymentToken.target).to.properAddress;

        const amountPaymentTokenToSend = ethers.parseUnits("10000", 6);

        // send 10k to borrower and investors
        await this.paymentToken.connect(owner).transfer(borrower.address, amountPaymentTokenToSend);
        await this.paymentToken.connect(owner).transfer(investor1.address, amountPaymentTokenToSend);
        await this.paymentToken.connect(owner).transfer(investor2.address, amountPaymentTokenToSend);

        expect(await this.paymentToken.balanceOf(borrower.address)).to.be.equal(amountPaymentTokenToSend);
        expect(await this.paymentToken.balanceOf(investor1.address)).to.be.equal(amountPaymentTokenToSend);
        expect(await this.paymentToken.balanceOf(investor2.address)).to.be.equal(amountPaymentTokenToSend);

        // Loan Anagrafica
        const name = ethers.encodeBytes32String("Loan Asset");
        const issuanceCountry = ethers.encodeBytes32String("IT");
        const currency = ethers.encodeBytes32String("EUR");
        const loanType = 0; // BULLET
        const interestRateType = 0; // FIXED
        // Date
        const startDate = Math.floor(Date.now() / 1000 + 10);
        this.firstRepaymentDate = startDate + 10;
        const maturityDate = this.firstRepaymentDate + 10;

        // Loan payment info
        const totalAmount = ethers.parseUnits("1000", 6);
        const goalAmount = ethers.parseUnits("900", 6); // owner want to sell his position
        const minimumDenomination = ethers.parseUnits("10", 6);
        const borrowerOustandingAmount = ethers.parseUnits("1000", 6);
        const interestRate = 500;
        const numbersRepayments = 2;

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

        loanPaymentInfo = {
            totalAmount: totalAmount,
            goalAmount: goalAmount,
            minimumDenomination: minimumDenomination,
            borrowerOustandingAmount: borrowerOustandingAmount,
            interestRate: interestRate,
            numbersRepayment: numbersRepayments,
        };

        const LoanAsset = await ethers.getContractFactory("LoanAssetFungible", owner);
        this.loanAsset = await LoanAsset.deploy(
            loanAnagInfo,
            borrower.address,
            loanPaymentInfo,
            this.paymentToken.target,
            this.ipfsDocumentationLink
        );

        expect(this.loanAsset.target).to.properAddress;
    });

    describe("Check contract loan asset data", function () {
        it("Should the contract has right loan data", async function () {
            let borrowerOutstandingAmount = loanPaymentInfo.borrowerOustandingAmount;
            let interestRate = BigInt(loanPaymentInfo.interestRate);
            // Check loan info
            expect(await this.loanAsset.NAME()).to.equal(loanAnagInfo.name);
            expect(await this.loanAsset.ISSUANCE_COUNTRY()).to.equal(loanAnagInfo.issuanceCountry);
            expect(await this.loanAsset.CURRENCY()).to.equal(loanAnagInfo.currency);

            expect(await this.loanAsset.TOTAL_AMOUNT()).to.equal(loanPaymentInfo.totalAmount);
            expect(await this.loanAsset.GOAL_AMOUNT()).to.equal(loanPaymentInfo.goalAmount);
            expect(await this.loanAsset.MINIMUM_DENOMINATION()).to.equal(loanPaymentInfo.minimumDenomination);

            expect(await this.loanAsset.START_DATE()).to.equal(loanAnagInfo.startDate);
            expect(await this.loanAsset.MATURITY_DATE()).to.equal(loanAnagInfo.maturityDate);
            expect(await this.loanAsset.LOAN_TYPE()).to.equal(loanAnagInfo.loanType);
            expect(await this.loanAsset.INTEREST_RATE_TYPE()).to.equal(loanAnagInfo.interestRateType);

            expect(await this.loanAsset.IPFS_DOCUMENTATION_LINK()).to.equal(this.ipfsDocumentationLink);
            expect(await this.loanAsset.BORROWER()).to.equal(borrower.address);
            expect(await this.loanAsset.TOTAL_REPAYMENT_NUMBER()).to.equal(BigInt(loanPaymentInfo.numbersRepayment));
            expect(await this.loanAsset.PAYMENT_TOKEN()).to.equal(this.paymentToken.target);

            expect(await this.loanAsset.currentLoanStatus()).to.equal(0); // 0 --> PRELIMINARY
            expect(await this.loanAsset.borrowerOutstandingPrincipalAmount()).to.equal(borrowerOutstandingAmount);
            expect(await this.loanAsset.currentRepaymentsIndex()).to.equal(0);

            //first repayment is normal and have only interest amount
            const firstRepayment = await this.loanAsset.repayments(0);
            expect(firstRepayment.interestRate).to.be.equal(interestRate);
            expect(firstRepayment.status).to.be.equal(1); // INITIALIZED
            expect(firstRepayment.interestAmount).to.be.equal(
                BigInt((borrowerOutstandingAmount * interestRate) / BigInt(10000))
            );
            expect(firstRepayment.principalAmount).to.be.equal(0);
            expect(firstRepayment.repaymentType).to.be.equal(0); // NORMAL

            // second repayment is PRINCIPAL and have interest and principal amount
            const principalRepayment = await this.loanAsset.repayments(1);
            expect(principalRepayment.interestRate).to.be.equal(interestRate);
            expect(principalRepayment.status).to.be.equal(1); // INITIALIZED
            expect(principalRepayment.interestAmount).to.be.equal(
                (borrowerOutstandingAmount * interestRate) / BigInt(10000)
            );
            expect(principalRepayment.principalAmount).to.be.equal(borrowerOutstandingAmount);
            expect(principalRepayment.repaymentType).to.be.equal(1); // PRINCIPAL
        });
    });
    describe("Whitelisting an unwhitelisting investors", function () {
        it("Owner whitelist all addresses", async function () {
            let addressToWhitelist = [investor1.address, investor2.address, borrower.address, owner.address];
            await this.loanAsset.connect(owner).whitelistInvestors(addressToWhitelist);

            expect((await this.loanAsset.investorsInfo(investor1.address)).isWhitelisted).to.be.true;
            expect((await this.loanAsset.investorsInfo(investor2.address)).isWhitelisted).to.be.true;
            expect((await this.loanAsset.investorsInfo(borrower.address)).isWhitelisted).to.be.true;
            expect((await this.loanAsset.investorsInfo(owner.address)).isWhitelisted).to.be.true;
        });
        it("Try to whitelist an investor already whitelisted", async function () {
            await expect(this.loanAsset.connect(owner).whitelistInvestor(investor1.address))
                .to.be.revertedWithCustomError(this.loanAsset, "InvestorAlreadyWhitelistedError")
                .withArgs("Investor is already whitelisted.", investor1.address);
        });
        it("Try to whitelist an zero address", async function () {
            await expect(this.loanAsset.connect(owner).whitelistInvestor(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(this.loanAsset, "ZeroAddressError")
                .withArgs("Investor address must be different from 0.");
        });
        it("Owner unwhitelist borrower and owner", async function () {
            let addressToUnwhitelist = [borrower.address, owner.address];
            await this.loanAsset.connect(owner).unwhitelistInvestors(addressToUnwhitelist);

            expect((await this.loanAsset.investorsInfo(borrower.address)).isWhitelisted).to.be.false;
            expect((await this.loanAsset.investorsInfo(owner.address)).isWhitelisted).to.be.false;
        });
        it("Owner unwhitelist investor1", async function () {
            expect(await this.loanAsset.connect(owner).unwhitelistInvestor(investor1.address))
                .to.emit(this.loanAsset, "InvestorUnwhitelistedEvent")
                .withArgs(investor1.address);

            expect((await this.loanAsset.investorsInfo(investor1.address)).isWhitelisted).to.be.false;
        });
        it("Try to unwhitelist an investor not whitelisted", async function () {
            await expect(this.loanAsset.connect(owner).unwhitelistInvestor(investor1.address))
                .to.be.revertedWithCustomError(this.loanAsset, "InvestorNotWhitelistedError")
                .withArgs("Investor is not whitelisted.", investor1.address);
        });
        it("Try to whitelist an zero address", async function () {
            await expect(this.loanAsset.connect(owner).unwhitelistInvestor(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(this.loanAsset, "ZeroAddressError")
                .withArgs("Investor address must be different from 0.");
        });
        it("Owner whitelist investor1", async function () {
            expect(await this.loanAsset.connect(owner).whitelistInvestor(investor1.address))
                .to.emit(this.loanAsset, "InvestorWhitelistedEvent")
                .withArgs(investor1.address);

            expect((await this.loanAsset.investorsInfo(investor1.address)).isWhitelisted).to.be.true;
            expect((await this.loanAsset.investorsInfo(investor2.address)).isWhitelisted).to.be.true;
            expect((await this.loanAsset.investorsInfo(borrower.address)).isWhitelisted).to.be.false;
            expect((await this.loanAsset.investorsInfo(owner.address)).isWhitelisted).to.be.false;
        });
    });
    describe("Investor period", function () {
        it("Owner set investor period", async function () {
            expect(await this.loanAsset.connect(owner).setInvestorPeriod()).to.emit(
                this.loanAsset,
                "LoanInvestorPeriodEvent"
            );

            expect(await this.loanAsset.currentLoanStatus()).to.be.equal(1); //INVESTor PERIOD
        });
        it("Shouldn't be able to whitelist other investor", async function () {
            await expect(this.loanAsset.connect(owner).whitelistInvestor(borrower.address))
                .to.be.revertedWithCustomError(this.loanAsset, "InvalidValueLoanStatusError")
                .withArgs("Invalid loan status.", 1, 0);
        });
        it("Investord deposits funds in SC", async function () {
            let depositAmount = ethers.parseUnits("400", 6);
            let investor1Balance = await this.paymentToken.balanceOf(investor1.address);
            let investor2Balance = await this.paymentToken.balanceOf(investor2.address);

            await this.paymentToken.connect(investor1).approve(this.loanAsset.target, depositAmount);
            await this.paymentToken.connect(investor2).approve(this.loanAsset.target, depositAmount);

            expect(await this.loanAsset.connect(investor1).depositFunds(depositAmount))
                .to.emit(this.loanAsset, "FundsDepositedEvent")
                .withArgs(investor1.address, depositAmount);
            expect(await this.loanAsset.connect(investor2).depositFunds(depositAmount))
                .to.emit(this.loanAsset, "FundsDepositedEvent")
                .withArgs(investor2.address, depositAmount);

            expect(await this.paymentToken.balanceOf(investor1.address)).to.be.equal(investor1Balance - depositAmount);
            expect(await this.paymentToken.balanceOf(investor2.address)).to.be.equal(investor2Balance - depositAmount);
            expect(await this.paymentToken.balanceOf(this.loanAsset.target)).to.be.equal(BigInt(2) * depositAmount);
        });
        it("Shouldn't distribute tokens to investor, check goals threshold not reached", async function () {
            await expect(this.loanAsset.connect(owner).checkGoals())
                .revertedWithCustomError(this.loanAsset, "InsufficientGoalAmountError")
                .withArgs("Insufficient goal amount.");
        });
        it("Investor1 add more funds and then Owner check goal and distribute tokens", async function () {
            let depositAmount = ethers.parseUnits("100", 6);
            // payment token
            let scBalance = await this.paymentToken.balanceOf(this.loanAsset.target);
            let investor1Balance = await this.paymentToken.balanceOf(investor1.address);
            let ownerBalance = await this.paymentToken.balanceOf(owner.address);
            // loan token
            let investor1AmountDeposited = (await this.loanAsset.investorsInfo(investor1.address)).amountDeposited;

            let balanceLoanTokensExpectedInvestor1 = investor1AmountDeposited + depositAmount;
            let balanceLoanTokensExpectedInvestor2 = (await this.loanAsset.investorsInfo(investor2.address))
                .amountDeposited;

            await this.paymentToken.connect(investor1).approve(this.loanAsset.target, depositAmount);
            expect(await this.loanAsset.connect(investor1).depositFunds(depositAmount))
                .to.emit(this.loanAsset, "FundsDepositedEvent")
                .withArgs(investor1.address, depositAmount);

            expect(await this.paymentToken.balanceOf(investor1.address)).to.be.equal(investor1Balance - depositAmount);
            expect(await this.paymentToken.balanceOf(this.loanAsset.target)).to.be.equal(scBalance + depositAmount);

            //check goals
            expect(await this.loanAsset.connect(owner).checkGoals()).to.emit(this.loanAsset, "LoanLiveEvent");

            expect(await this.loanAsset.balanceOf(investor1.address)).to.be.equal(balanceLoanTokensExpectedInvestor1);
            expect(await this.loanAsset.balanceOf(investor2.address)).to.be.equal(balanceLoanTokensExpectedInvestor2);

            expect(await this.paymentToken.balanceOf(owner.address)).to.be.equal(
                ownerBalance + scBalance + depositAmount
            );

            expect(await this.loanAsset.currentLoanStatus()).to.be.equal(2); // LIVE
            expect(await this.loanAsset.totalSupply()).to.be.equal(ethers.parseUnits("900", 6));
        });
        it("Shouldn't able to call again checkGoals or try to refund investors", async function () {
            await expect(this.loanAsset.connect(owner).checkGoals())
                .revertedWithCustomError(this.loanAsset, "InvalidValueLoanStatusError")
                .withArgs("Invalid loan status.", 2, 1);
            await expect(this.loanAsset.connect(owner).refundInvestors())
                .revertedWithCustomError(this.loanAsset, "InvalidValueLoanStatusError")
                .withArgs("Invalid loan status.", 2, 1);
        });
    });
    describe("Interest Distributions - first repayment", function () {
        it("Only owner can enable repayment", async function () {
            await expect(this.loanAsset.connect(borrower).enableRepayment())
                .revertedWithCustomError(this.loanAsset, "OwnableUnauthorizedAccount")
                .withArgs(borrower.address);
        });
        it("Shouldn't able to pay repayment if it is not enabled", async function () {
            let borrowerOutstandingAmount = loanPaymentInfo.borrowerOustandingAmount;
            let interestRate = BigInt(loanPaymentInfo.interestRate);
            this.amountRepaymentToPay = (borrowerOutstandingAmount * interestRate) / BigInt(10000);

            await expect(this.loanAsset.connect(borrower).payRepayment(this.amountRepaymentToPay))
                .revertedWithCustomError(this.loanAsset, "InvalidRepaymentStatusError")
                .withArgs("Repayment must be enabled.", 0);
        });
        it("Enable next repayment", async function () {
            let repayment = await this.loanAsset.repayments(0);
            expect(repayment.status).to.be.equal(1); //INITIALIZED

            await this.loanAsset.connect(owner).enableRepayment();

            repayment = await this.loanAsset.repayments(0);
            expect(repayment.status).to.be.equal(2); //ENABLED
        });
        it("Shouldn't able enable repayment twice", async function () {
            await expect(this.loanAsset.connect(owner).enableRepayment())
                .revertedWithCustomError(this.loanAsset, "InvalidRepaymentStatusError")
                .withArgs("Repayment must be initialized.", 0);
        });
        it("Shouldn't execute repayment if borrower try to pay a wrong amount", async function () {
            await expect(this.loanAsset.connect(borrower).payRepayment(this.amountRepaymentToPay + BigInt(1)))
                .revertedWithCustomError(this.loanAsset, "InvalidValueError")
                .withArgs("Amount must be equal to the calculated amount.");

            await expect(this.loanAsset.connect(borrower).payRepayment(0))
                .revertedWithCustomError(this.loanAsset, "InvalidZeroValueError")
                .withArgs("Amount must be greater than zero.");
        });
        it("Borrower pay repayment", async function () {
            let scBalance = await this.paymentToken.balanceOf(this.loanAsset.target);
            let borrowerBalance = await this.paymentToken.balanceOf(borrower.address);

            // borrower need to approve SC to spend his funds
            await this.paymentToken.connect(borrower).approve(this.loanAsset.target, this.amountRepaymentToPay);
            expect(await this.loanAsset.connect(borrower).payRepayment(this.amountRepaymentToPay))
                .to.emit(this.loanAsset, "RepaymentPaidEvent")
                .withArgs(borrower.address, this.amountRepaymentToPay, 0);

            let repayment = await this.loanAsset.repayments(0);
            expect(repayment.status).to.be.equal(3); //PAID

            expect(await this.paymentToken.balanceOf(this.loanAsset.target)).to.be.equal(
                scBalance + this.amountRepaymentToPay
            );
            expect(await this.paymentToken.balanceOf(borrower.address)).to.be.equal(
                borrowerBalance - this.amountRepaymentToPay
            );
        });
        it("Owner distributes interest", async function () {
            let scBalance = await this.paymentToken.balanceOf(this.loanAsset.target);
            let investor1Balance = await this.paymentToken.balanceOf(investor1.address);
            let investor2Balance = await this.paymentToken.balanceOf(investor2.address);

            expect(await this.loanAsset.connect(owner).distributeInterest()).to.emit(
                this.loanAsset,
                "InterestPaidEvent"
            );

            expect(await this.loanAsset.currentRepaymentsIndex()).to.equal(1);

            // NB the last investor is investor1 in this case because he was whitelisted and unwhitelisted in this test
            let amountInvestor2 =
                (this.amountRepaymentToPay * ethers.parseUnits("400", 6)) / ethers.parseUnits("900", 6);
            let amountInvestor1 = this.amountRepaymentToPay - amountInvestor2;

            expect(await this.paymentToken.balanceOf(this.loanAsset.target)).to.be.equal(
                scBalance - this.amountRepaymentToPay
            );
            expect(await this.paymentToken.balanceOf(investor1.address)).to.be.equal(
                investor1Balance + amountInvestor1
            );
            expect(await this.paymentToken.balanceOf(investor2.address)).to.be.equal(
                investor2Balance + amountInvestor2
            );
        });
    });
    describe("Principal Distributions - last repayment", function () {
        it("Only owner can set matured the loan", async function () {
            await expect(this.loanAsset.connect(borrower).setMatured())
                .revertedWithCustomError(this.loanAsset, "OwnableUnauthorizedAccount")
                .withArgs(borrower.address);
        });
        it("Borrower shouldn't able to pay principal if status is not matured", async function () {
            let borrowerOutstandingAmount = loanPaymentInfo.borrowerOustandingAmount;
            let interestRate = BigInt(loanPaymentInfo.interestRate);
            this.amountToPayLastRepayment =
                borrowerOutstandingAmount + (borrowerOutstandingAmount * interestRate) / BigInt(10000);

            await expect(this.loanAsset.connect(borrower).payPrincipal(this.amountToPayLastRepayment))
                .revertedWithCustomError(this.loanAsset, "InvalidValueLoanStatusError")
                .withArgs("Invalid loan status.", 2, 3);
        });
        it("Ownner set to matured the loan", async function () {
            expect(await this.loanAsset.connect(owner).setMatured()).to.emit(this.loanAsset, "LoanMaturedEvent");
            expect(await this.loanAsset.currentLoanStatus()).to.be.equal(3); // MATURED

            // check that last repayment was enabled
            let repayment = await this.loanAsset.repayments(1);
            expect(repayment.status).to.be.equal(2); //ENABLED
        });
        it("Shouldn't execute repayment if borrower try to pay a wrong amount", async function () {
            await expect(this.loanAsset.connect(borrower).payPrincipal(this.amountToPayLastRepayment + BigInt(1)))
                .revertedWithCustomError(this.loanAsset, "InvalidValueError")
                .withArgs("Amount must be equal to the calculated amount.");

            await expect(this.loanAsset.connect(borrower).payPrincipal(0))
                .revertedWithCustomError(this.loanAsset, "InvalidZeroValueError")
                .withArgs("Amount must be greater than zero.");
        });
        it("Borrower pay principal", async function () {
            let scBalance = await this.paymentToken.balanceOf(this.loanAsset.target);
            let borrowerBalance = await this.paymentToken.balanceOf(borrower.address);

            // borrower need to approve SC to spend his funds
            await this.paymentToken.connect(borrower).approve(this.loanAsset.target, this.amountToPayLastRepayment);
            expect(await this.loanAsset.connect(borrower).payPrincipal(this.amountToPayLastRepayment))
                .to.emit(this.loanAsset, "PrincipalPaidEvent")
                .withArgs(borrower.address, this.amountToPayLastRepayment);

            let repayment = await this.loanAsset.repayments(1);
            expect(repayment.status).to.be.equal(3); //PAID

            expect(await this.paymentToken.balanceOf(this.loanAsset.target)).to.be.equal(
                scBalance + this.amountToPayLastRepayment
            );
            expect(await this.paymentToken.balanceOf(borrower.address)).to.be.equal(
                borrowerBalance - this.amountToPayLastRepayment
            );
        });
        it("Investors reedems their tokens", async function () {
            let investor1Balance = await this.paymentToken.balanceOf(investor1.address);
            let investor2Balance = await this.paymentToken.balanceOf(investor2.address);

            let investor1AmountToReceive =
                (this.amountToPayLastRepayment *
                    (await this.loanAsset.investorsInfo(investor1.address)).amountDeposited) /
                ethers.parseUnits("900", 6);
            let investor2AmountToReceive = this.amountToPayLastRepayment - investor1AmountToReceive;

            await this.loanAsset.connect(investor1).redeemTokens();
            expect(await this.loanAsset.balanceOf(investor1.address)).to.be.equal(0);
            expect(await this.paymentToken.balanceOf(investor1.address)).to.be.equal(
                investor1Balance + investor1AmountToReceive
            );
            // check error if investor try to redeem again
            await expect(this.loanAsset.connect(investor1).redeemTokens())
                .revertedWithCustomError(this.loanAsset, "InvalidZeroValueError")
                .withArgs("Amount must be greater than zero.");

            await this.loanAsset.connect(investor2).redeemTokens();

            expect(await this.loanAsset.balanceOf(investor2.address)).to.be.equal(0);
            expect(await this.paymentToken.balanceOf(investor2.address)).to.be.equal(
                investor2Balance + investor2AmountToReceive
            );

            expect(await this.paymentToken.balanceOf(this.loanAsset.target)).to.be.equal(0);
        });
        it("Shouldn't able to recall redeemTokens after all investors reedems their tokens", async function () {
            await expect(this.loanAsset.connect(investor1).redeemTokens())
                .revertedWithCustomError(this.loanAsset, "InvalidValueError")
                .withArgs("No active investors remaining.");
        });
    });
    describe("Close Loan", function () {
        it("Only owner can close the loan", async function () {
            await expect(this.loanAsset.connect(borrower).setClose())
                .revertedWithCustomError(this.loanAsset, "OwnableUnauthorizedAccount")
                .withArgs(borrower.address);
        });
        it("Owner close the loan", async function () {
            expect(await this.loanAsset.connect(owner).setClose()).to.emit(this.loanAsset, "LoanClosedEvent");
            expect(await this.loanAsset.currentLoanStatus()).to.be.equal(4); // CLOSED
        });
    });
});
