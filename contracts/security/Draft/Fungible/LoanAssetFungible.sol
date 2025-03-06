// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./ILoanAssetFungible.sol";
import "./LoanAssetFungibleLib.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./module/utils/Pausable.sol";
import "./module/utils/ReentrancyGuard.sol";
import "./module/utils/Ownable.sol";

contract LoanAssetFungible is
    ILoanAssetFungible,
    ERC20,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    /* LOAN DRAFT

    REVIEW CODE
    CREATE TEST
    CREATE PROXY

    This contract rappresents the tokenized part of Loan hold by the owner. It will be a fungible token, where tokens gives the rights to the holder to receive interest and principal of the loan.

    Investor will be registered by the owner in the preliminary state of the SC.
    
    Only a whitelisted investor can deposit funds and receive the token. Deposit funds are allowed only during the INVESTING_PERIOD status.


    The owner will mint the token to the investors during the investor period (INVESTING STATUS) if the threshold is reached (maybe more checks). 
    The owner will also be able to burn the token if the loan is closed and all the principal and interest are paid (TODO automatic burn).

    The Developers will repay interest and principal to the contract, and the contract will distribute the funds to the investors.

    The contract will have a status, and the owner will be able to change the status of the contract.

    Information about the underlyng loan will be stored in the contract during the deployment.

    TODO
    mint
    burn

    TODO override ERC20 functions like transfer: send only to whitelisted addresses

    */
    // ##################################################################
    // ############################ STATE ###############################
    // ##################################################################

    // LOAN INFO
    bytes32 public immutable NAME;
    bytes32 public immutable ISSUANCE_COUNTRY;
    bytes32 public immutable CURRENCY;

    uint256 public immutable TOTAL_AMOUNT;
    uint256 public immutable START_DATE; // loan start epoch time
    uint256 public immutable MATURITY_DATE; // maturity date loan epoch time
    uint256 public immutable MINIMUM_DENOMINATION;

    LoanAssetFungibleLib.LoanTypeEnum public immutable LOAN_TYPE;
    LoanAssetFungibleLib.InterestRateTypeEnum
        public immutable INTEREST_RATE_TYPE;
    LoanAssetFungibleLib.LoanStatusEnum public currentLoanStatus;

    string public IPFS_DOCUMENTATION_LINK;

    // BORROWER INFO
    address public immutable BORROWER;
    uint256 public borrowerRepaymentsIndex;
    uint256 public borrowerOutstandingPrincipalAmount;

    // INVESTORS
    mapping(address => bool) public whitelistedInvestors;
    // i need an array to loop over the investors when the SC distribute the funds
    address[] public investors;

    // PAYMENT DETAILS
    uint256 public immutable TOTAL_REPAYMENT_NUMBER;
    mapping(uint256 => LoanAssetFungibleLib.RepaymentInfo) public repayments;
    ERC20 public immutable PAYMENT_TOKEN; // stable coin or fake payment token

    // ##################################################################
    // #################### REMOVED DEFAULT PAYMENT #####################
    // ##################################################################
    // receive() external payable {}

    // fallback() external payable {}

    // #####################################################################
    // ############################ MODIFIER ###############################
    // #####################################################################

    // only borrower
    modifier onlyBorrower() {
        if (msg.sender != BORROWER) {
            revert InvalidACLBorrowerError(
                "Only the borrower can perform this action.",
                msg.sender
            );
        }
        _;
    }

    // only whitelisted investor
    modifier onlyWhitelistedInvestor() {
        if (!whitelistedInvestors[msg.sender]) {
            revert InvalidACLInvestorError(
                "Only whitelisted investor can perform this action.",
                msg.sender
            );
        }
        _;
    }

    // modifier to check the loan status
    modifier whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum _status) {
        if (currentLoanStatus != _status) {
            revert InvalidValueLoanStatusError(
                "Invalid loan status.",
                currentLoanStatus,
                _status
            );
        }
        _;
    }

    modifier whenLoanInterestType(
        LoanAssetFungibleLib.InterestRateTypeEnum _interestRateType
    ) {
        if (INTEREST_RATE_TYPE != _interestRateType) {
            revert InvalidValueInterestRateTypeError(
                "Invalid interest rate type.",
                INTEREST_RATE_TYPE,
                _interestRateType
            );
        }
        _;
    }

    // ##################################################################
    // ############################ EVENT ###############################
    // ##################################################################

    // ##################################################################
    // ######################### CONSTRUCTOR ############################
    // ##################################################################
    constructor(
        LoanAssetFungibleLib.LoanAnagInfo memory _loanAnagInfo,
        address _borrower,
        LoanAssetFungibleLib.LoanPaymentInfo memory _loanPaymentInfo,
        address _paymentToken,
        string memory _ipfsDocumentationLink
    ) Ownable(msg.sender) ERC20("LoanAssetFungible", "LOAN") {
        // check anag
        if (_loanAnagInfo.name == "") {
            revert InvalidEmptyValueError(
                "Name must be different from empty string."
            );
        }

        if (_loanAnagInfo.issuanceCountry == "") {
            revert InvalidEmptyValueError(
                "Issuance country must be different from empty string."
            );
        }

        if (_loanAnagInfo.currency == "") {
            revert InvalidEmptyValueError(
                "Currency must be different from empty string."
            );
        }

        if (_loanAnagInfo.startDate <= block.timestamp) {
            revert InvalidDateError(
                "Start date must be in the future.",
                block.timestamp,
                _loanAnagInfo.startDate
            );
        }

        if (_loanAnagInfo.maturityDate <= block.timestamp) {
            revert InvalidDateError(
                "Maturity date must be in the future.",
                block.timestamp,
                _loanAnagInfo.maturityDate
            );
        }

        if (_loanAnagInfo.startDate >= _loanAnagInfo.maturityDate) {
            revert InvalidMathRestrictionStartMaturityDateError(
                "Start date must be before maturity date.",
                _loanAnagInfo.startDate,
                _loanAnagInfo.maturityDate
            );
        }

        // check loan participant and payment info
        if (_loanPaymentInfo.totalAmount == 0) {
            revert InvalidZeroValueError(
                "Total amount must be greater than zero."
            );
        }

        // check minimum denomination
        if (_loanPaymentInfo.minimumDenomination == 0) {
            revert InvalidZeroValueError(
                "Minimum denomination must be greater than zero."
            );
        }

        // check minimum denomination is a multiple
        if (
            _loanPaymentInfo.totalAmount %
                _loanPaymentInfo.minimumDenomination !=
            0
        ) {
            revert InvalidValueError(
                "Total amount must be a multiple of the minimum denomination."
            );
        }

        if (_loanPaymentInfo.repaymentsDates.length == 0) {
            revert InvalidZeroLenghtError(
                "Repayment dates must be greater than zero."
            );
        }

        // check that lenght of interest rates is the same of repayment dates
        if (
            _loanPaymentInfo.interestRates.length !=
            _loanPaymentInfo.repaymentsDates.length
        ) {
            revert InvalidLengthInterestRateForRepaymentDateError(
                "Mismatch in interest rate and borrowers.",
                _loanPaymentInfo.interestRates.length,
                _loanPaymentInfo.repaymentsDates.length
            );
        }

        // borrower outstanding must be <= total amount
        if (
            _loanPaymentInfo.totalAmount <
            _loanPaymentInfo.borrowerOustandingAmount
        ) {
            revert InvalidValueError(
                "Borrower outstanding amount must be less or equal to the total amount."
            );
        }

        //check zero address
        if (_borrower == address(0)) {
            revert ZeroAddressError(
                "Borrower address must be different from 0."
            );
        }
        if (_paymentToken == address(0)) {
            revert ZeroAddressError(
                "Payment token address must be different from 0."
            );
        }

        NAME = _loanAnagInfo.name;
        ISSUANCE_COUNTRY = _loanAnagInfo.issuanceCountry;
        CURRENCY = _loanAnagInfo.currency;
        TOTAL_AMOUNT = _loanPaymentInfo.totalAmount;
        START_DATE = _loanAnagInfo.startDate;
        MATURITY_DATE = _loanAnagInfo.maturityDate;
        LOAN_TYPE = _loanAnagInfo.loanType;
        INTEREST_RATE_TYPE = _loanAnagInfo.interestRateType;
        TOTAL_REPAYMENT_NUMBER = _loanPaymentInfo.repaymentsDates.length;
        MINIMUM_DENOMINATION = _loanPaymentInfo.minimumDenomination;
        BORROWER = _borrower;
        borrowerRepaymentsIndex = 0;
        borrowerOutstandingPrincipalAmount = _loanPaymentInfo
            .borrowerOustandingAmount;

        PAYMENT_TOKEN = ERC20(_paymentToken);

        IPFS_DOCUMENTATION_LINK = _ipfsDocumentationLink;

        currentLoanStatus = LoanAssetFungibleLib.LoanStatusEnum.PRELIMINARY;

        emit LoanTokenizedEvent(NAME, Ownable.owner(), TOTAL_AMOUNT);
    }

    // ###############################################################
    // ######################### FUNCTION ############################
    // ###############################################################

    function whitelistInvestors(
        address[] calldata _investors
    ) external onlyOwner {
        uint256 investorsLength = _investors.length;
        for (uint256 _investorIndex = 0; _investorIndex < investorsLength; ) {
            whitelistInvestor(_investors[_investorIndex]);
            unchecked {
                _investorIndex++;
            }
        }
    }

    function whitelistInvestor(address _investor) public onlyOwner {
        _whitelist(_investor);
    }

    function _whitelist(address _investor) internal {
        if (_investor == address(0)) {
            revert ZeroAddressError(
                "Investor address must be different from 0."
            );
        }
        if (whitelistedInvestors[_investor]) {
            revert InvestorAlreadyWhitelistedError(
                "Investor is already whitelisted.",
                _investor
            );
        }
        whitelistedInvestors[_investor] = true;
        investors.push(_investor);
    }

    function setInvestorPeriod() external onlyOwner {
        if (
            currentLoanStatus != LoanAssetFungibleLib.LoanStatusEnum.PRELIMINARY
        ) {
            revert InvalidValueLoanStatusError(
                "Loan status must be preliminary.",
                currentLoanStatus,
                LoanAssetFungibleLib.LoanStatusEnum.PRELIMINARY
            );
        }
        currentLoanStatus = LoanAssetFungibleLib.LoanStatusEnum.INVESTOR_PERIOD;
    }

    function _depositFunds(address _from, uint256 _amount) internal {
        if (
            currentLoanStatus !=
            LoanAssetFungibleLib.LoanStatusEnum.INVESTOR_PERIOD
        ) {
            revert InvalidValueLoanStatusError(
                "Loan status must be investor period.",
                currentLoanStatus,
                LoanAssetFungibleLib.LoanStatusEnum.INVESTOR_PERIOD
            );
        }

        if (_amount % MINIMUM_DENOMINATION != 0) {
            revert InvalidValueError(
                "Amount must be a multiple of the minimum denomination."
            );
        }

        // other checks to do?

        // devo salvare l'ammontare che ha depositato l'investor
        PAYMENT_TOKEN.transferFrom(_from, address(this), MINIMUM_DENOMINATION);
    }

    function depositFunds(uint256 _amount) external onlyWhitelistedInvestor {
        _depositFunds(msg.sender, _amount);
    }
}
