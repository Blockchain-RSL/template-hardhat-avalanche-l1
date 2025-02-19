// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./ILoanAsset.sol";
import "./LoanAssetLib.sol";

contract LoanAsset is ILoanAsset {
    /* LOAN DRAFT

    
    // TODO NEXT STEPS:
    // change repayment calculation with the formula
    // define the minimum denomination of the share
    // add ERC20 token

    REVIEW CODE
    CREATE TEST
    CREATE PROXY

    Lender and Borrowers: 
    The contract is deployed by a issuer who sets the loan details, 
    including borrowers and their shares in the loan. 
     
    Borrowers are tracked by their status, share percentage, outstanding principal, and remaining repayments.
    Lenders are tracked by their shares in the loan.

    Loan Types: Amortized and Bullet
    Interest Rate Type: Fixed and Floating
    Loan Status: Preliminary, Live, Matured, Closed
    Repayment Status: Undefined, Unpaid, Paid
    Borrower Status: disabled, enabled, Repaid, Defaulted, Anticipated

    Loan Issuance:
    The issuer deploys the contract and sets the loan details, 
    including the loan name, issuance country, currency, total amount, 
    start date, maturity date, interest rate, loan type, 
    interest rate type, and repayment dates.

    TODO IMPORTANT: THE FLOATING INTEREST RATE MUST BE UPDATED MANUALLY FOR EACH REPAYMENT SO
    ALL REPAYMENT ARE NOT CREATED AT START, BUT THE INTEREST RATE CAN BE UPDATED CREATING NEW REPAYMENTS 
    (OR UPDATING THE EXISTING ONES)
    TODO IMPORTANT: THE FIXED INTEREST RATE IS SET AT START FOR ALL REPAYMENTS

    Borrowers are added with their share percentage in the loan.

    Loan Start:
    The issuer can start the loan after the start date.

    Interest Rate Update:
    The issuer can update the interest rate for floating loans.

    Repayments:
    Borrowers can pay their repayments based on the payment date and amount.

    Principal Payment:
    Borrowers can pay the principal amount after the loan matures.

    Default:
    The issuer can set a borrower's status to defaulted.

    Anticipate Payment:
    Borrowers can request to pay the loan early.

    Loan Maturity:
    The issuer can set the loan status to matured after the maturity date.

    Loan Closure:
    The lender can close the loan after all borrowers have paid their outstanding principal and repayments.

    Withdraw Funds:
    A allowed lender can withdraw the funds from the contract after the loan is closed.

    Pausing:
    The contract can be paused and unpaused by the issuer.

    Access Control:
    The contract uses access control to restrict certain functions to the issuer.

    Reentrancy Guard:
    The contract uses a reentrancy guard to prevent reentrancy attacks.

    Events:
    The contract emits events for 
    funds deposited,
    loan issuance, 
    loan funded,
    interest rate updates, 
    loan start, 
    repayments,
    principal payments, 
    loan maturity, 
    and loan closure.

    // Repayment logic
    // - The borrower can pay the repayment only after the payment date has been reached.
    // - The Repayment amount is calculated based on the outstanding principal amount.
    // - The borrower can pay the Repayment amount to the contract.
    // - After the Repayment is paid, IF AMORTIZED the outstanding principal amount is reduced by the Repayment amount.
    // - The borrower's status is updated to repaid if all Repayments are paid.


    */

    // ##################################################################
    // ############################ STATE ###############################
    // ##################################################################

    // LOAN INFO
    address public immutable ISSUER;

    bytes32 public immutable NAME;
    bytes32 public immutable ISSUANCE_COUNTRY;
    bytes32 public immutable CURRENCY;

    uint256 public immutable TOTAL_AMOUNT;
    uint256 public immutable START_DATE; // loan start epoch time
    uint256 public immutable MATURITY_DATE; // maturity date loan epoch time

    LoanAssetLib.LoanTypeEnum public immutable LOAN_TYPE;
    LoanAssetLib.InterestRateTypeEnum public immutable INTEREST_RATE_TYPE;
    LoanAssetLib.LoanStatusEnum public currentLoanStatus;

    uint256 public immutable MINIMUM_DENOMINATION_PER_SHARE;

    string public IPFS_DOCUMENTATION_LINK;

    // LENDER
    address[] public lenders;
    mapping(address => LoanAssetLib.LenderInfo) public lendersInfo; // lenders info

    // BORROWER
    address[] public borrowers; // needed for iterations
    mapping(address => LoanAssetLib.BorrowerInfo) public borrowersInfo; // borrowers info

    // PAYMENT DETAILS
    uint256 public immutable TOTAL_REPAYMENT_NUMBER;
    mapping(uint256 => uint256) public REPAYMENTS_DATES;

    mapping(address => mapping(uint256 => LoanAssetLib.RepaymentInfo))
        public borrowersRepayments; // repayment info for each borrower
    mapping(address => LoanAssetLib.OutstandingInfo)
        public borrowersOutstandingPrincipals; // principal amount remained to be paid by the borrower

    // UTILS CONTRACT
    // until 0.8.24 solidity, use _locked to prevent reentrancy
    bool private _locked;

    // is paused flag
    bool private _isPaused;

    // ##################################################################
    // #################### REMOVED DEFAULT PAYMENT #####################
    // ##################################################################
    // receive() external payable {}

    // fallback() external payable {}

    // #####################################################################
    // ############################ MODIFIER ###############################
    // #####################################################################
    // Modifier allowing lender to perform actions
    modifier onlyOwner() {
        if (msg.sender != ISSUER) {
            revert InvalidACLOwnerError(
                "Only the issuer can perform this action.",
                msg.sender
            );
        }
        _;
    }

    // only enable borrower
    modifier onlyEnabledBorrower() {
        if (
            borrowersInfo[msg.sender].status !=
            LoanAssetLib.BorrowerStatusEnum.ENABLED
        ) {
            revert InvalidACLBorrowerError(
                "Only a enabled borrower can perform this action.",
                msg.sender
            );
        }
        _;
    }

    modifier onlyEnabledLender() {
        if (
            lendersInfo[msg.sender].status !=
            LoanAssetLib.LenderStatusEnum.ENABLED
        ) {
            revert("Only a enabled lender can perform this action.");
        }
        _;
    }

    modifier onlyDepositedLender() {
        if (
            lendersInfo[msg.sender].status !=
            LoanAssetLib.LenderStatusEnum.DEPOSITED
        ) {
            revert("Only a lender who deposited can perform this action.");
        }
        _;
    }

    // prevent reentrancy
    modifier nonReentrant() {
        if (_locked) {
            revert ReentrancyGuardError("ReentrancyGuard: reentrant call");
        }

        _locked = true;

        _;

        _locked = false;
    }

    // modifier to check if the contract is paused
    modifier whenNotPaused() {
        if (_isPaused) {
            revert PausedError("Contract is paused");
        }
        _;
    }

    // modifier to check the loan status
    modifier whenLoanStatus(LoanAssetLib.LoanStatusEnum _status) {
        if (currentLoanStatus != _status) {
            revert InvalidValueLoanStatus(
                "Invalid loan status.",
                currentLoanStatus,
                _status
            );
        }
        _;
    }

    modifier whenLoanInterestType(
        LoanAssetLib.InterestRateTypeEnum _interestRateType
    ) {
        if (INTEREST_RATE_TYPE != _interestRateType) {
            revert InvalidValueInterestRateType(
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
    event Paused();
    event Unpaused();

    // ##################################################################
    // ######################### CONSTRUCTOR ############################
    // ##################################################################
    constructor(
        LoanAssetLib.LoanAnagInfo memory _loanAnagInfo,
        LoanAssetLib.LoanParticipantInfo memory _loanParticipantInfo,
        LoanAssetLib.LoanPaymentInfo memory _loanPaymentInfo,
        string memory _ipfsDocumentationLink
    ) {
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

        // if (_loanAnagInfo.startDate <= block.timestamp) {
        //     revert InvalidMathRestrictionStartMaturityDateError(
        //         "Start date must be in the future.",
        //         _loanAnagInfo.startDate,
        //         block.timestamp
        //     );
        // }

        // if (_loanAnagInfo.maturityDate <= block.timestamp) {
        //     revert InvalidMathRestrictionStartMaturityDateError(
        //         "Maturity date must be in the future.",
        //         _loanAnagInfo.maturityDate,
        //         block.timestamp
        //     );
        // }

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

        // check length borrower
        if (_loanParticipantInfo.borrowers.length == 0) {
            revert InvalidZeroLenghtError(
                "Borrowers must be greater than zero."
            );
        }

        if (
            _loanParticipantInfo.borrowers.length !=
            _loanParticipantInfo.borrowersShares.length
        ) {
            revert InvalidLengthSharesForBorrowerError(
                "Mismatch in borrowers and shares.",
                _loanParticipantInfo.borrowersShares.length,
                _loanParticipantInfo.borrowers.length
            );
        }

        // check length lender
        if (_loanParticipantInfo.lenders.length == 0) {
            revert InvalidZeroLenghtError("Lenders must be greater than zero.");
        }

        if (
            _loanParticipantInfo.lenders.length !=
            _loanParticipantInfo.lendersShares.length
        ) {
            revert InvalidLengthSharesForLenderError(
                "Mismatch in lenders and shares.",
                _loanParticipantInfo.lendersShares.length,
                _loanParticipantInfo.lenders.length
            );
        }

        if (
            _loanPaymentInfo.spreadForBorrower.length !=
            _loanParticipantInfo.borrowers.length
        ) {
            revert InvalidLenghtInterestRateForBorrower(
                "Mismatch in borrowers and spread.",
                _loanPaymentInfo.spreadForBorrower.length,
                _loanParticipantInfo.borrowers.length
            );
        }

        if (
            _loanPaymentInfo.interestRates.length !=
            _loanParticipantInfo.borrowers.length
        ) {
            revert InvalidLengthInterestRateForBorrowerError(
                "Mismatch in borrowers and interest rates.",
                _loanPaymentInfo.interestRates.length,
                _loanParticipantInfo.borrowers.length
            );
        }

        if (_loanPaymentInfo.repaymentsDates.length == 0) {
            revert InvalidZeroLenghtError(
                "Repayment dates must be greater than zero."
            );
        }

        // start set state
        ISSUER = msg.sender;

        NAME = _loanAnagInfo.name;
        ISSUANCE_COUNTRY = _loanAnagInfo.issuanceCountry;
        CURRENCY = _loanAnagInfo.currency;
        TOTAL_AMOUNT = _loanPaymentInfo.totalAmount;
        START_DATE = _loanAnagInfo.startDate;
        MATURITY_DATE = _loanAnagInfo.maturityDate;
        LOAN_TYPE = _loanAnagInfo.loanType;
        INTEREST_RATE_TYPE = _loanAnagInfo.interestRateType;
        TOTAL_REPAYMENT_NUMBER = _loanPaymentInfo.repaymentsDates.length;
        MINIMUM_DENOMINATION_PER_SHARE = _loanPaymentInfo.minimumDenomination;

        IPFS_DOCUMENTATION_LINK = _ipfsDocumentationLink;

        // set repayment dates
        uint256 repaymentsLength = _loanPaymentInfo.repaymentsDates.length; // gas optimization
        for (uint256 repaymentIndex = 0; repaymentIndex < repaymentsLength; ) {
            REPAYMENTS_DATES[repaymentIndex] = _loanPaymentInfo.repaymentsDates[
                repaymentIndex
            ];
            unchecked {
                repaymentIndex++;
            }
        }

        // set lenders
        uint256 lendersLength = _loanParticipantInfo.lenders.length; // gas optimization
        for (uint256 lenderIndex = 0; lenderIndex < lendersLength; ) {
            address lender = _loanParticipantInfo.lenders[lenderIndex];
            uint256 shares = _loanParticipantInfo.lendersShares[lenderIndex];

            if (shares == 0) {
                revert InvalidZeroValueError(
                    "Lender share must be greater than zero."
                );
            }

            // check if share is minimum denomination
            if (
                (_loanPaymentInfo.totalAmount / shares) %
                    _loanPaymentInfo.minimumDenomination !=
                0
            ) {
                revert InvalidValueError(
                    "Shares must be a multiple of the minimum denomination."
                );
            }

            // set lender status
            lenders.push(lender);
            lendersInfo[lender] = LoanAssetLib.LenderInfo({
                status: LoanAssetLib.LenderStatusEnum.ENABLED,
                shares: shares
            });

            unchecked {
                lenderIndex++;
            }
        }

        // set percentage of shares for each borrower and repayment
        uint256 borrowersLength = _loanParticipantInfo.borrowers.length; // gas optimization
        for (uint256 borrowerIndex = 0; borrowerIndex < borrowersLength; ) {
            address borrower = _loanParticipantInfo.borrowers[borrowerIndex];
            uint256 shares = _loanParticipantInfo.borrowersShares[
                borrowerIndex
            ];

            if (shares == 0) {
                revert InvalidZeroValueError(
                    "Borrower share must be greater than zero."
                );
            }

            // check if share is minimum denomination
            if (
                (_loanPaymentInfo.totalAmount / shares) %
                    _loanPaymentInfo.minimumDenomination !=
                0
            ) {
                revert InvalidValueError(
                    "Shares must be a multiple of the minimum denomination."
                );
            }

            // set borrower status
            borrowers.push(borrower);
            borrowersInfo[borrower] = LoanAssetLib.BorrowerInfo({
                status: LoanAssetLib.BorrowerStatusEnum.ENABLED,
                shares: shares,
                spread: _loanPaymentInfo.spreadForBorrower[borrowerIndex]
            });

            // set outstanding principal amount and repayment number left to pay
            borrowersOutstandingPrincipals[borrower] = LoanAssetLib
                .OutstandingInfo({
                    outstandingPrincipalAmount: (shares *
                        MINIMUM_DENOMINATION_PER_SHARE),
                    nextRepaymentIndex: 1,
                    anticipatedRepaymentAmount: 0
                });

            // if IR fixed, calculate repayment amount for each borrower and all next repayments
            if (
                _loanAnagInfo.interestRateType ==
                LoanAssetLib.InterestRateTypeEnum.FIXED
            ) {
                for (
                    uint256 repaymentIndex = 0;
                    repaymentIndex < repaymentsLength;

                ) {
                    // create repayments
                    borrowersRepayments[
                        _loanParticipantInfo.borrowers[borrowerIndex]
                    ][repaymentIndex] = _createNextRepayment(
                        _loanPaymentInfo.repaymentsDates[repaymentIndex],
                        _loanPaymentInfo.interestRates[borrowerIndex]
                    );

                    unchecked {
                        repaymentIndex++;
                    }
                }
            } else if (
                _loanAnagInfo.interestRateType ==
                LoanAssetLib.InterestRateTypeEnum.FLOATING
            ) {
                /* if floating and the IR must be inserted for each repayment manually, so set only the first one
                and the next ones are going to be defined with the update interest rate */
                borrowersRepayments[
                    _loanParticipantInfo.borrowers[borrowerIndex]
                ][0] = _createNextRepayment(
                    _loanPaymentInfo.repaymentsDates[0],
                    _loanPaymentInfo.interestRates[borrowerIndex]
                );
            } else {
                revert UnknownValueInterestRateType(
                    "Unknown interest rate type.",
                    _loanAnagInfo.interestRateType
                );
            }

            unchecked {
                borrowerIndex++;
            }
        }

        currentLoanStatus = LoanAssetLib.LoanStatusEnum.PRELIMINARY;

        emit LoanIssuedEvent(NAME, ISSUER, TOTAL_AMOUNT);
    }

    // ###############################################################
    // ######################### FUNCTION ############################
    // ###############################################################

    // pause contract
    function pause() external onlyOwner {
        _isPaused = true;
        emit Paused();
    }

    // unpause contract
    function unpause() external onlyOwner {
        _isPaused = false;
        emit Unpaused();
    }

    // deposit funds for the loan
    function depositFunds()
        external
        payable
        override
        onlyEnabledLender
        whenLoanStatus(LoanAssetLib.LoanStatusEnum.PRELIMINARY)
    {
        uint256 amountToFund = (lendersInfo[msg.sender].shares *
            MINIMUM_DENOMINATION_PER_SHARE);
        if (msg.value != amountToFund) {
            revert InvalidAmountToFund(
                "Invalid Deposit amount.",
                amountToFund,
                msg.value
            );
        }

        lendersInfo[msg.sender].status = LoanAssetLib
            .LenderStatusEnum
            .DEPOSITED;

        emit FundsDepositedEvent(msg.sender, msg.value);
    }

    function calculateNextRepaymentAmount() public view returns (uint256) {
        return _calculateNextRepaymentAmountByBorrower(msg.sender);
    }

    function calculatePrincipalAmount() public view returns (uint256) {
        return _calculatePrincipalAmountByBorrower(msg.sender);
    }

    // Over the start date, the loan can be started
    function setLoanStart()
        external
        override
        onlyOwner
        whenLoanStatus(LoanAssetLib.LoanStatusEnum.PRELIMINARY)
    {
        currentLoanStatus = LoanAssetLib.LoanStatusEnum.LIVE;

        // moves token to each borrower
        for (uint256 borrowerIndex = 0; borrowerIndex < borrowers.length; ) {
            address borrower = borrowers[borrowerIndex];

            // transfer native token into the smart contract to the borrowers
            address payable borrowerAddress = payable(borrower);
            uint256 amount = (borrowersInfo[borrower].shares *
                MINIMUM_DENOMINATION_PER_SHARE);

            borrowerAddress.transfer(amount);
            unchecked {
                borrowerIndex++;
            }
        }

        emit LoanStartedEvent();
    }

    // set interest rate
    function updateInterestRateAndRepayments(
        address[] calldata _borrowers,
        uint256[] calldata _interestRates
    )
        external
        onlyOwner
        whenLoanStatus(LoanAssetLib.LoanStatusEnum.LIVE)
        whenLoanInterestType(LoanAssetLib.InterestRateTypeEnum.FLOATING)
    {
        if (_interestRates.length == 0) {
            revert InvalidZeroLenghtError(
                "Interest length IR must be greater than zero."
            );
        }

        uint256 borrowersLength = _borrowers.length; // gas optimization

        if (_interestRates.length != borrowersLength) {
            revert InvalidLenghtInterestRateForBorrower(
                "Mismatch in interest rate and borrowers.",
                _interestRates.length,
                borrowersLength
            );
        }

        if (INTEREST_RATE_TYPE != LoanAssetLib.InterestRateTypeEnum.FLOATING) {
            revert InvalidValueInterestRateType(
                "Interest rate type must be floating in order to update interest rate.",
                INTEREST_RATE_TYPE,
                LoanAssetLib.InterestRateTypeEnum.FLOATING
            );
        }

        // update interest rate
        for (uint256 borrowerIndex = 0; borrowerIndex < borrowersLength; ) {
            address borrowerAddress = _borrowers[borrowerIndex];
            updateInterestRateByBorrower(
                borrowerAddress,
                _interestRates[borrowerIndex]
            );

            unchecked {
                borrowerIndex++;
            }
        }

        emit UpdateInterestRateAndRepaymentsEvent(_interestRates);
    }

    function updateInterestRateByBorrower(
        address _borrowerAddress,
        uint256 _interestRate
    )
        public
        onlyOwner
        whenLoanStatus(LoanAssetLib.LoanStatusEnum.LIVE)
        whenLoanInterestType(LoanAssetLib.InterestRateTypeEnum.FLOATING)
    {
        LoanAssetLib.BorrowerInfo memory borrowerInfo = borrowersInfo[
            _borrowerAddress
        ];

        if (borrowerInfo.status != LoanAssetLib.BorrowerStatusEnum.ENABLED) {
            revert InvalidValueBorrowerStatus(
                "Borrower must be enabled.",
                borrowerInfo.status,
                LoanAssetLib.BorrowerStatusEnum.ENABLED
            );
        }

        // set next repayment amount for each borrower
        LoanAssetLib.OutstandingInfo
            memory borrowerOutstandingInfo = borrowersOutstandingPrincipals[
                _borrowerAddress
            ];

        // update repayment info
        borrowersRepayments[_borrowerAddress][
            borrowerOutstandingInfo.nextRepaymentIndex
        ] = LoanAssetLib.RepaymentInfo({
            paymentDate: REPAYMENTS_DATES[
                borrowerOutstandingInfo.nextRepaymentIndex
            ],
            interestRate: _interestRate,
            status: LoanAssetLib.RepaymentStatusEnum.UNPAID
        });
    }

    // Borrower request to pay a repayment
    function payRepayment(
        uint256 repaymentIndex
    )
        external
        payable
        nonReentrant
        onlyEnabledBorrower
        whenLoanStatus(LoanAssetLib.LoanStatusEnum.LIVE)
    {
        // check loan status
        LoanAssetLib.OutstandingInfo
            storage borrowerOutstandingInfo = borrowersOutstandingPrincipals[
                msg.sender
            ];

        if (repaymentIndex >= TOTAL_REPAYMENT_NUMBER) {
            revert InvalidValueRepaymentIndex(
                "Invalid repayment number.",
                TOTAL_REPAYMENT_NUMBER,
                repaymentIndex
            );
        }

        LoanAssetLib.RepaymentInfo storage repaymentInfo = borrowersRepayments[
            msg.sender
        ][repaymentIndex];

        // check on repayment status
        if (repaymentInfo.status != LoanAssetLib.RepaymentStatusEnum.UNPAID) {
            revert InvalidStatusRepayFromAllBorrowers(
                "Repayment is not in status unpaid.",
                msg.sender,
                repaymentInfo.status,
                LoanAssetLib.RepaymentStatusEnum.UNPAID
            );
        }

        if (repaymentInfo.paymentDate > block.timestamp) {
            revert InvalidMathRestrictionStartMaturityDateError(
                "Repayment date has not been reached yet.",
                repaymentInfo.paymentDate,
                block.timestamp
            );
        }

        // check on amount
        uint256 repaymentAmount = _calculateNextRepaymentAmountByBorrower(
            msg.sender
        );
        if (repaymentAmount == 0) {
            revert InvalidZeroValueError(
                "Repayment must be defined before being paid."
            );
        }

        if (msg.value != repaymentAmount) {
            revert InvalidValueError("Incorrect repayment amount sent.");
        }

        // update outstanding info
        if (LoanAssetLib.LoanTypeEnum.AMORTIZED == LOAN_TYPE) {
            borrowerOutstandingInfo
                .outstandingPrincipalAmount -= repaymentAmount;
        }
        borrowerOutstandingInfo.nextRepaymentIndex++;

        // update repayment status
        repaymentInfo.status = LoanAssetLib.RepaymentStatusEnum.PAID;

        // payment from msg.sender to smart contract on the payable function
        // TODO ERC20 transfer

        emit RepaymentPaidEvent(msg.sender, repaymentAmount, repaymentIndex);
    }

    // Pay principal
    function payPrincipal()
        external
        payable
        override
        nonReentrant
        onlyEnabledBorrower
        whenLoanStatus(LoanAssetLib.LoanStatusEnum.MATURED)
    {
        // check loan status
        if (currentLoanStatus != LoanAssetLib.LoanStatusEnum.MATURED) {
            revert InvalidValueLoanStatus(
                "Loan is not matured.",
                currentLoanStatus,
                LoanAssetLib.LoanStatusEnum.MATURED
            );
        }

        uint256 principalAmount = _calculatePrincipalAmountByBorrower(
            msg.sender
        );
        if (principalAmount <= 0) {
            revert InvalidZeroValueError(
                "No outstanding principal amount to pay."
            );
        }

        if (msg.value != principalAmount) {
            revert InvalidValueError("Incorrect principal amount sent.");
        }

        LoanAssetLib.OutstandingInfo
            storage borrowerOutstandingInfo = borrowersOutstandingPrincipals[
                msg.sender
            ];

        // if (borrowerOutstandingInfo.outstandingPrincipalAmount == 0) {
        //     revert InvalidZeroValueError(
        //         "No outstanding principal amount to pay."
        //     );
        // }
        // if (msg.value != borrowerOutstandingInfo.outstandingPrincipalAmount) {
        //     revert InvalidValueError("Incorrect principal amount sent.");
        // }

        // update outstanding principal amount and repayment number left to pay
        borrowerOutstandingInfo.outstandingPrincipalAmount = 0;
        borrowerOutstandingInfo.nextRepaymentIndex = 0;

        // update borrower status
        borrowersInfo[msg.sender].status = LoanAssetLib
            .BorrowerStatusEnum
            .REPAID;

        // payment from msg.sender to smart contract on the payable function
        // TODO ERC20 transfer

        emit LoanRepaidEvent(msg.sender, msg.value);
    }

    function setDefault(address borrower) external onlyOwner {
        if (
            borrowersInfo[borrower].status !=
            LoanAssetLib.BorrowerStatusEnum.ENABLED
        ) {
            revert InvalidACLBorrowerError(
                "Borrower is not enabled.",
                borrower
            );
        }

        borrowersInfo[borrower].status = LoanAssetLib
            .BorrowerStatusEnum
            .DEFAULTED;
    }

    function enableAnticipatePayment(
        address _borrower,
        uint256 _totalAmountToAnticipate
    ) external onlyOwner whenLoanStatus(LoanAssetLib.LoanStatusEnum.LIVE) {
        if (
            borrowersInfo[_borrower].status !=
            LoanAssetLib.BorrowerStatusEnum.ENABLED
        ) {
            revert InvalidACLBorrowerError(
                "Borrower is not enabled to anticipate payment.",
                _borrower
            );
        }

        if (_totalAmountToAnticipate <= 0) {
            revert InvalidZeroValueError(
                "Total amount to anticipate must be greater than zero."
            );
        }

        // check borrower outstanding
        LoanAssetLib.OutstandingInfo
            storage borrowerOutstandingInfo = borrowersOutstandingPrincipals[
                _borrower
            ];

        if (borrowerOutstandingInfo.outstandingPrincipalAmount <= 0) {
            revert InvalidZeroValueError(
                "No outstanding principal amount left to pay."
            );
        }

        borrowerOutstandingInfo
            .anticipatedRepaymentAmount = _totalAmountToAnticipate;

        borrowersInfo[msg.sender].status = LoanAssetLib
            .BorrowerStatusEnum
            .ANTICIPATED;
    }

    function disableAnticipatePayment(
        address borrower
    ) external onlyOwner whenLoanStatus(LoanAssetLib.LoanStatusEnum.LIVE) {
        if (
            borrowersInfo[msg.sender].status !=
            LoanAssetLib.BorrowerStatusEnum.ANTICIPATED
        ) {
            revert InvalidACLBorrowerError(
                "Borrower is not enabled to anticipate payment.",
                msg.sender
            );
        }

        borrowersOutstandingPrincipals[borrower].anticipatedRepaymentAmount = 0;

        borrowersInfo[msg.sender].status = LoanAssetLib
            .BorrowerStatusEnum
            .ENABLED;
    }

    function anticipatePayment()
        external
        payable
        nonReentrant
        whenLoanStatus(LoanAssetLib.LoanStatusEnum.LIVE)
    {
        if (
            borrowersInfo[msg.sender].status !=
            LoanAssetLib.BorrowerStatusEnum.ANTICIPATED
        ) {
            revert InvalidACLBorrowerError(
                "Borrower is not enabled to anticipate payment.",
                msg.sender
            );
        }

        address borrower = msg.sender;

        LoanAssetLib.OutstandingInfo
            storage borrowerOutstandingInfo = borrowersOutstandingPrincipals[
                borrower
            ];

        uint256 paymentAmount = borrowerOutstandingInfo
            .anticipatedRepaymentAmount;

        if (msg.value < paymentAmount) {
            revert InsufficientFunds(
                "Insufficient funds to anticipate payment."
            );
        }

        // update outstanding principal amount and repayment number left to pay
        borrowerOutstandingInfo.outstandingPrincipalAmount = 0;
        borrowerOutstandingInfo.nextRepaymentIndex = 0;

        // update borrower status
        borrowersInfo[borrower].status = LoanAssetLib.BorrowerStatusEnum.REPAID;

        // payment from msg.sender to smart contract on the payable function
        // TODO ERC20 transfer

        emit LoanRepaidEvent(borrower, paymentAmount);
    }

    // set loan matured request
    function setLoanMatured()
        external
        override
        onlyOwner
        whenLoanStatus(LoanAssetLib.LoanStatusEnum.LIVE)
    {
        if (block.timestamp < MATURITY_DATE) {
            revert InvalidMathRestrictionStartMaturityDateError(
                "Loan has not matured yet.",
                block.timestamp,
                MATURITY_DATE
            );
        }
        currentLoanStatus = LoanAssetLib.LoanStatusEnum.MATURED;

        emit LoanMaturedEvent();
    }

    // close loan request
    function setLoanClosed()
        external
        override
        onlyOwner
        whenLoanStatus(LoanAssetLib.LoanStatusEnum.MATURED)
    {
        // check each borrower paid outstanding principal amount (so implicit repayments)
        uint256 borrowersLength = borrowers.length; // gas optimization
        for (uint256 borrowersIndex = 0; borrowersIndex < borrowersLength; ) {
            // if some borrower has not paid all the repayments, revert
            if (
                borrowersOutstandingPrincipals[borrowers[borrowersIndex]]
                    .outstandingPrincipalAmount != 0
            ) {
                revert InvalidAmountRepayFromAllBorrowers(
                    "All borrowers must pay all repayments before closing.",
                    borrowers[borrowersIndex],
                    borrowersOutstandingPrincipals[borrowers[borrowersIndex]]
                        .outstandingPrincipalAmount,
                    0
                );
            }

            unchecked {
                borrowersIndex++;
            }
        }

        currentLoanStatus = LoanAssetLib.LoanStatusEnum.CLOSED;

        emit LoanClosedEvent();
    }

    function withdrawFunds()
        external
        override
        nonReentrant
        onlyDepositedLender
        whenLoanStatus(LoanAssetLib.LoanStatusEnum.CLOSED)
    {
        // TODO switch to ERC20 and avoid the 1e18
        uint256 amountToWithDraw = ((address(this).balance *
            lendersInfo[msg.sender].shares) / 100);
        (bool success, ) = msg.sender.call{value: amountToWithDraw}("");
        if (!success) {
            revert InvalidACLBorrowerError("Transfer failed.", msg.sender);
        }
    }

    function getRepaymentInfo(
        uint256 repaymentIndex
    ) external view returns (LoanAssetLib.RepaymentInfo memory) {
        return borrowersRepayments[msg.sender][repaymentIndex];
    }

    // ############################################################### //
    // ######################## PRIVATE FUNCTION ##################### //
    // ############################################################### //

    // create next repayment
    function _createNextRepayment(
        uint256 _paymentDate,
        uint256 _interestRate
    ) private pure returns (LoanAssetLib.RepaymentInfo memory repaymentInfo) {
        return
            LoanAssetLib.RepaymentInfo({
                paymentDate: _paymentDate,
                interestRate: _interestRate,
                status: LoanAssetLib.RepaymentStatusEnum.UNPAID
            });
    }

    // calculate amount to pay based on outstanding
    function _calculateNextRepaymentAmountByBorrower(
        address _borrower
    ) private view returns (uint256) {
        LoanAssetLib.OutstandingInfo
            memory borrowerOutstandingInfo = borrowersOutstandingPrincipals[
                _borrower
            ];

        LoanAssetLib.RepaymentInfo
            memory borrowerRepaymentInfo = borrowersRepayments[_borrower][
                borrowerOutstandingInfo.nextRepaymentIndex
            ];

        LoanAssetLib.BorrowerInfo memory borrowerInfo = borrowersInfo[
            _borrower
        ];

        /* TODO amount = (outstanding * ir) / (1 - (1+ ir)^-repayment left ) for amortized instrument*/
        uint256 interestMatured = (borrowerOutstandingInfo
            .outstandingPrincipalAmount *
            (borrowerRepaymentInfo.interestRate +
                borrowerInfo.spread)); /*interest*/
        if (LoanAssetLib.LoanTypeEnum.AMORTIZED == LOAN_TYPE) {
            uint256 repaymentsCountLeftToPay = TOTAL_REPAYMENT_NUMBER -
                borrowerOutstandingInfo.nextRepaymentIndex +
                1; // for principal payment
            return
                (borrowerOutstandingInfo.outstandingPrincipalAmount /
                    repaymentsCountLeftToPay) /* principal */ +
                interestMatured; /*interest*/
        } else if (LoanAssetLib.LoanTypeEnum.BULLET == LOAN_TYPE) {
            return interestMatured; /*interest*/
        } else {
            revert InvalidValueLoanType("Invalid loan type.", LOAN_TYPE);
        }
    }

    // calculate amount to pay based on outstanding
    function _calculatePrincipalAmountByBorrower(
        address _borrower
    ) private view returns (uint256) {
        LoanAssetLib.OutstandingInfo
            memory borrowerOutstandingInfo = borrowersOutstandingPrincipals[
                _borrower
            ];

        LoanAssetLib.RepaymentInfo
            memory borrowerRepaymentInfo = borrowersRepayments[_borrower][
                borrowerOutstandingInfo.nextRepaymentIndex
            ];

        LoanAssetLib.BorrowerInfo memory borrowerInfo = borrowersInfo[
            _borrower
        ];

        /* TODO formula for principal to define */
        uint256 interestMatured = (borrowerOutstandingInfo
            .outstandingPrincipalAmount *
            (borrowerRepaymentInfo.interestRate +
                borrowerInfo.spread)); /*interest*/
        return
            borrowerOutstandingInfo.outstandingPrincipalAmount /* principal */ +
            interestMatured; /*interest*/
    }
}
