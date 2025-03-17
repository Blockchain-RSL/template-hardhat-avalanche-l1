const { expect } = require("chai");
const { ethers } = require("hardhat");
const { extendProvider } = require("hardhat/config");

describe("Custom stablecoin test", function () {
    let registrar, account1, account2, faucet;
    let restrictionsLayer1, customStablecoin;

    before(async function () {
        [registrar, account1, account2, faucet] = await ethers.getSigners();

        const RestrinctionsLayer1 = await ethers.getContractFactory("RestrictionsLayer1");
        restrictionsLayer1 = await RestrinctionsLayer1.deploy();

        await restrictionsLayer1.addWhitelistAddress([account1.address, account2.address]);

        const CustomStablecoin = await ethers.getContractFactory("CustomStablecoin");
        customStablecoin = await CustomStablecoin.deploy("TestStable", "TSTCOIN", restrictionsLayer1.target);
    });

    describe("Checks after deploys", function () {
        it("Check contracts addresses", async function () {
            expect(restrictionsLayer1.target).to.properAddress;
            expect(customStablecoin.target).to.properAddress;
        });
        it("Check address whitelisted", async function () {
            expect(await restrictionsLayer1.isWhitelisted(account1.address)).to.be.true;
            expect(await restrictionsLayer1.isWhitelisted(account2.address)).to.be.true;
        });
    });

    describe("Minting test", function () {
        it("Mint stable to account1", async function () {
            const amountToMint = ethers.parseUnits("2000", 18);
            expect(await customStablecoin.connect(registrar).mint(account1.address, amountToMint))
                .to.emit(customStablecoin, "Transfer")
                .withArgs(ethers.AddressZero, account1.address, amountToMint);
            expect(await customStablecoin.balanceOf(account1.address)).to.be.equal(amountToMint);
        });
        it("Revert trying to mint stable to an account not whitelisted", async function () {
            await expect(customStablecoin.connect(registrar).mint(faucet.address, 1000))
                .to.be.revertedWithCustomError(customStablecoin, "AccountNotWhitelisted")
                .withArgs("Recipient is not whitelisted", faucet.address);
        });
        // account that is not registrar try to mint
        it("Revert trying to mint stable with an account that is not registrar", async function () {
            await expect(customStablecoin.connect(account1).mint(account2.address, 1000))
                .to.be.revertedWithCustomError(customStablecoin, "InvalidRegistrar")
                .withArgs("Caller is not a admin", account1.address);
        });
    });

    describe("Transfer test", function () {
        it("Transfer stable from account1 to account2", async function () {
            const amountToTransfer = ethers.parseUnits("500", 18);
            expect(await customStablecoin.connect(account1).transfer(account2.address, amountToTransfer))
                .to.emit(customStablecoin, "Transfer")
                .withArgs(account1.address, account2.address, amountToTransfer);
            expect(await customStablecoin.balanceOf(account1.address)).to.be.equal(ethers.parseUnits("1500", 18));
            expect(await customStablecoin.balanceOf(account2.address)).to.be.equal(ethers.parseUnits("500", 18));
        });
        it("Revert trying to transfer more stable than the balance", async function () {
            await expect(
                customStablecoin.connect(account1).transfer(account2.address, ethers.parseUnits("2000", 18))
            ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
        });
        it("Revert trying to transfer stable to an account not whitelisted", async function () {
            await expect(customStablecoin.connect(account1).transfer(faucet.address, ethers.parseUnits("100", 18)))
                .to.be.revertedWithCustomError(customStablecoin, "AccountNotWhitelisted")
                .withArgs("Recipient is not whitelisted", faucet.address);
        });
    });

    describe("TransferFrom test", function () {
        it("Approve account2 to transfer stable from account1", async function () {
            const amountToApprove = ethers.parseUnits("200", 18);
            expect(await customStablecoin.connect(account1).approve(account2.address, amountToApprove))
                .to.emit(customStablecoin, "Approval")
                .withArgs(account1.address, account2.address, amountToApprove);
            expect(await customStablecoin.allowance(account1.address, account2.address)).to.be.equal(amountToApprove);
        });
        it("Transfer stable from account1 to account2 using account2 allowance", async function () {
            const amountToTransfer = ethers.parseUnits("100", 18);
            expect(
                await customStablecoin
                    .connect(account2)
                    .transferFrom(account1.address, account2.address, amountToTransfer)
            )
                .to.emit(customStablecoin, "Transfer")
                .withArgs(account1.address, account2.address, amountToTransfer);
            expect(await customStablecoin.balanceOf(account1.address)).to.be.equal(ethers.parseUnits("1400", 18));
            expect(await customStablecoin.balanceOf(account2.address)).to.be.equal(ethers.parseUnits("600", 18));
        });
        it("Revert trying to transfer more stable than the allowance", async function () {
            await expect(
                customStablecoin
                    .connect(account2)
                    .transferFrom(account1.address, account2.address, ethers.parseUnits("1000", 18))
            ).to.be.revertedWith("ERC20: insufficient allowance");
        });
        it("Revert trying to transfer stable to an account not whitelisted", async function () {
            await expect(
                customStablecoin
                    .connect(account2)
                    .transferFrom(account1.address, faucet.address, ethers.parseUnits("100", 18))
            )
                .to.be.revertedWithCustomError(customStablecoin, "AccountNotWhitelisted")
                .withArgs("Recipient is not whitelisted", faucet.address);
        });
    });

    describe("Forced Transfer test", function () {
        it("Forced transfer stable from account1 to account2", async function () {
            const amountToTransfer = ethers.parseUnits("100", 18);
            expect(
                await customStablecoin
                    .connect(registrar)
                    .forceTransfer(account1.address, account2.address, amountToTransfer)
            )
                .to.emit(customStablecoin, "Transfer")
                .withArgs(account1.address, account2.address, amountToTransfer);
            expect(await customStablecoin.balanceOf(account1.address)).to.be.equal(ethers.parseUnits("1300", 18));
            expect(await customStablecoin.balanceOf(account2.address)).to.be.equal(ethers.parseUnits("700", 18));
        });
        it("Revert trying to transfer more stable than the balance", async function () {
            await expect(
                customStablecoin
                    .connect(registrar)
                    .forceTransfer(account1.address, account2.address, ethers.parseUnits("2000", 18))
            ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
        });
        it("Revert trying to forse transfer stable to an account not whitelisted", async function () {
            await expect(
                customStablecoin
                    .connect(registrar)
                    .forceTransfer(account1.address, faucet.address, ethers.parseUnits("100", 18))
            )
                .to.be.revertedWithCustomError(customStablecoin, "AccountNotWhitelisted")
                .withArgs("Recipient is not whitelisted", faucet.address);
        });
        it("Revert trying to force transfer stable with an account that is not registrar", async function () {
            await expect(
                customStablecoin
                    .connect(account1)
                    .forceTransfer(account1.address, account2.address, ethers.parseUnits("100", 18))
            )
                .to.be.revertedWithCustomError(customStablecoin, "InvalidRegistrar")
                .withArgs("Caller is not a admin", account1.address);
        });
    });

    describe("Burn test", function () {
        it("Burn stable from account1", async function () {
            const amountToBurn = ethers.parseUnits("100", 18);
            expect(await customStablecoin.connect(registrar).burn(account1.address, amountToBurn))
                .to.emit(customStablecoin, "Transfer")
                .withArgs(account1.address, ethers.AddressZero, amountToBurn);
            expect(await customStablecoin.balanceOf(account1.address)).to.be.equal(ethers.parseUnits("1200", 18));
        });
        it("Revert trying to burn more stable than the balance", async function () {
            await expect(
                customStablecoin.connect(registrar).burn(account1.address, ethers.parseUnits("2000", 18))
            ).to.be.revertedWith("ERC20: burn amount exceeds balance");
        });
        it("Revert trying to burn stable with an account that is not registrar", async function () {
            await expect(customStablecoin.connect(account1).burn(account1.address, ethers.parseUnits("100", 18)))
                .to.be.revertedWithCustomError(customStablecoin, "InvalidRegistrar")
                .withArgs("Caller is not a admin", account1.address);
        });
    });

    describe("Pause test", function () {
        it("Revert trying to pause the contract with an account that is not registrar", async function () {
            await expect(customStablecoin.connect(account1).pause())
                .to.be.revertedWithCustomError(customStablecoin, "InvalidRegistrar")
                .withArgs("Caller is not a admin", account1.address);
        });
        it("Pause the contract", async function () {
            expect(await customStablecoin.connect(registrar).pause())
                .to.emit(customStablecoin, "Paused")
                .withArgs(registrar.address);
            await expect(
                customStablecoin.connect(account1).transfer(account2.address, ethers.parseUnits("100", 18))
            ).to.be.revertedWith("Pausable: paused");
        });

        // tryng to transfer o transferFrom when the contract is paused
        it("Revert trying to transfer stable when the contract is paused", async function () {
            await expect(
                customStablecoin.connect(account2).transfer(account1.address, ethers.parseUnits("100", 18))
            ).to.be.revertedWith("Pausable: paused");
        });

        it("Revert trying to transferFrom stable when the contract is paused", async function () {
            await expect(
                customStablecoin
                    .connect(account2)
                    .transferFrom(account1.address, account2.address, ethers.parseUnits("100", 18))
            ).to.be.revertedWith("Pausable: paused");
        });

        it("Unpause the contract", async function () {
            expect(await customStablecoin.connect(registrar).unpause())
                .to.emit(customStablecoin, "Unpaused")
                .withArgs(registrar.address);
            expect(await customStablecoin.connect(account2).transfer(account1.address, ethers.parseUnits("100", 18)))
                .to.emit(customStablecoin, "Transfer")
                .withArgs(account2.address, account1.address, ethers.parseUnits("100", 18));
        });
    });

    describe("Others test: balanceOf, totalSupply and setRestrictionsLayer", function () {
        it("Revert trying getBalance with an account not whitelisted", async function () {
            await expect(customStablecoin.connect(faucet).balanceOf(account1.address))
                .to.be.revertedWithCustomError(customStablecoin, "AccountNotWhitelisted")
                .withArgs("Caller is not whitelisted", faucet.address);
        });
        it("Revert trying getTotalSupply with an account not whitelisted", async function () {
            await expect(customStablecoin.connect(faucet).totalSupply())
                .to.be.revertedWithCustomError(customStablecoin, "AccountNotWhitelisted")
                .withArgs("Caller is not whitelisted", faucet.address);
        });
        it("Set new restrictions layer", async function () {
            const newRestrictionsLayer = await (await ethers.getContractFactory("RestrictionsLayer1")).deploy();
            expect(await customStablecoin.connect(registrar).setRestrictionsSmartContract(newRestrictionsLayer.target))
                .to.emit(customStablecoin, "RestrictionsLayerChanged")
                .withArgs(newRestrictionsLayer.target);
        });
        // now transfer from account1 to account2 should be reverted
        it("Revert trying to transfer stable from account1 to account2", async function () {
            await expect(customStablecoin.connect(account1).transfer(account2.address, ethers.parseUnits("100", 18)))
                .to.be.revertedWithCustomError(customStablecoin, "AccountNotWhitelisted")
                .withArgs("Caller is not whitelisted", account1.address);
        });
    });
});
