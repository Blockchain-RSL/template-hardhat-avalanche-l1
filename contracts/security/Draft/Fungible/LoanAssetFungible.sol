// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./ILoanAssetFungible.sol";
import "./LoanAssetFungibleLib.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

    // ##################################################################
    // ############################ STATE ###############################
    // ##################################################################

    // LOAN INFO
    bytes32 public immutable NAME;
    bytes32 public immutable ISSUANCE_COUNTRY;
    bytes32 public immutable CURRENCY;

    uint256 public immutable TOTAL_AMOUNT;
    uint256 public immutable GOAL_AMOUNT;
    uint256 public immutable START_DATE; // loan start epoch time
    uint256 public immutable MATURITY_DATE; // maturity date loan epoch time
    uint256 public immutable MINIMUM_DENOMINATION;
    uint256 public currentRepaymentsIndex;


    LoanAssetFungibleLib.LoanTypeEnum public immutable LOAN_TYPE;
    LoanAssetFungibleLib.InterestRateTypeEnum
        public immutable INTEREST_RATE_TYPE;
    LoanAssetFungibleLib.LoanStatusEnum public currentLoanStatus;

    string public IPFS_DOCUMENTATION_LINK;

    // BORROWER INFO
    address public immutable BORROWER;
    uint256 public borrowerOutstandingPrincipalAmount;

    // INVESTORS
    mapping(address => LoanAssetFungibleLib.InvestorInfo) public investorsInfo;
    // i need an array to loop over the investors when the SC distribute the funds
    address[] public investors;

    // PAYMENT DETAILS
    uint256 public immutable TOTAL_REPAYMENT_NUMBER;
    mapping(uint256 => LoanAssetFungibleLib.RepaymentInfo) public repayments;
    IERC20 public immutable PAYMENT_TOKEN; // stable coin or fake payment token

    uint256 private _totalDeposited;
    uint256 private _numInvestorsActive;
    uint256 private _remainingLastRepayment; // number of investors that have deposited funds and not yet redeemed


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
        if (!investorsInfo[msg.sender].isWhitelisted) {
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

        if (_loanPaymentInfo.goalAmount == 0) {
            revert InvalidZeroValueError(
                "Goal amount must be greater than zero."
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

        if (_loanPaymentInfo.numbersRepayment == 0) {
            revert InvalidZeroValueError(
                "Number of repayment must be greater than zero."
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
        GOAL_AMOUNT = _loanPaymentInfo.goalAmount;
        START_DATE = _loanAnagInfo.startDate;
        MATURITY_DATE = _loanAnagInfo.maturityDate;
        LOAN_TYPE = _loanAnagInfo.loanType;
        INTEREST_RATE_TYPE = _loanAnagInfo.interestRateType;
        TOTAL_REPAYMENT_NUMBER = _loanPaymentInfo.numbersRepayment;
        MINIMUM_DENOMINATION = _loanPaymentInfo.minimumDenomination;
        BORROWER = _borrower;
        currentRepaymentsIndex = 0;
        borrowerOutstandingPrincipalAmount = _loanPaymentInfo.borrowerOustandingAmount;

        //handle creation repayments if FIXED, if FLOATING use updateInterest for create the next repayment
        if(INTEREST_RATE_TYPE == LoanAssetFungibleLib.InterestRateTypeEnum.FIXED) {
            uint256 principalRemaining = _loanPaymentInfo.borrowerOustandingAmount;
            for (uint256 index = 0; index < _loanPaymentInfo.numbersRepayment;) {

                (uint256 interestAmount, uint256 principalAmount, LoanAssetFungibleLib.RepaymentTypeEnum repaymentType) = _calculateAmountRepayment(
                    _loanPaymentInfo.interestRate, principalRemaining, index
                );

                repayments[index] = LoanAssetFungibleLib.RepaymentInfo({
                    interestRate: _loanPaymentInfo.interestRate,
                    status: LoanAssetFungibleLib.RepaymentStatusEnum.INITIALIZED,
                    interestAmount: interestAmount,
                    principalAmount: principalAmount,
                    repaymentType: repaymentType
                });

                principalRemaining -= principalAmount;

                unchecked {index++;}
            }
        // } else if (INTEREST_RATE_TYPE == LoanAssetFungibleLib.InterestRateTypeEnum.FLOATING) {
        //     repayments[currentRepaymentsIndex].status = LoanAssetFungibleLib.RepaymentStatusEnum.NOT_ALREADY_DEFINED;
        // } // non devo farlo essendo di default lo stato NOT_ALREADY_DEFINED
        }

        PAYMENT_TOKEN = ERC20(_paymentToken);

        IPFS_DOCUMENTATION_LINK = _ipfsDocumentationLink;

        currentLoanStatus = LoanAssetFungibleLib.LoanStatusEnum.PRELIMINARY;

        emit LoanTokenizedEvent(NAME, Ownable.owner(), TOTAL_AMOUNT);
    }

    // ###############################################################
    // ######################### FUNCTION ############################
    // ###############################################################

     function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function whitelistInvestors(address[] calldata _investors) external onlyOwner whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.PRELIMINARY) {
        uint256 investorsLength = _investors.length;
        for (uint256 _investorIndex = 0; _investorIndex < investorsLength; ) {
            _whitelistInvestor(_investors[_investorIndex]);
            unchecked {
                _investorIndex++;
            }
        }
    }

    function unwhitelistInvestors(address[] calldata _investors) external onlyOwner whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.PRELIMINARY) {
        uint256 investorsLength = _investors.length;
        for (uint256 _investorIndex = 0; _investorIndex < investorsLength; ) {
            _unwhitelistInvestor(_investors[_investorIndex]);
            unchecked {
                _investorIndex++;
            }
        }
    }

    function whitelistInvestor(address _investor) public onlyOwner whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.PRELIMINARY) {
        _whitelistInvestor(_investor);
    }

    function unwhitelistInvestor(address _investor) public onlyOwner whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.PRELIMINARY) {
        _unwhitelistInvestor(_investor);
    }

    function setInvestorPeriod() external onlyOwner whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.PRELIMINARY) {
        currentLoanStatus = LoanAssetFungibleLib.LoanStatusEnum.INVESTOR_PERIOD;

        emit LoanInvestorPeriodEvent();
    }

     function depositFunds(uint256 _amount) external onlyWhitelistedInvestor {
        _depositFunds(msg.sender, _amount);
    }

    function getTotalDeposit() external onlyOwner view returns (uint256) {
        return _totalDeposited;
    }

    function checkGoals() external onlyOwner whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.INVESTOR_PERIOD) {
        if (_totalDeposited < GOAL_AMOUNT) {
            revert InsufficientGoalAmountError("Insufficient goal amount.");
        }
        _distributeLoanTokens();

        currentLoanStatus = LoanAssetFungibleLib.LoanStatusEnum.LIVE;

        bool success = PAYMENT_TOKEN.transfer(msg.sender, _totalDeposited);
        if(!success) {
            revert TransferERC20Error("Error during the transfer of the funds.");
        }
    }

    function refundInvestors() external onlyOwner whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.INVESTOR_PERIOD) {
        // TODO bisogna fare dei check sul balance dello SC? vengono comunque fatti nel transfer
        _setClose();
        _refundInvestors();
    }

    function mint(address _to, uint256 _amount) public onlyOwner() whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.INVESTOR_PERIOD) {
        if(!investorsInfo[_to].isWhitelisted) {
            revert InvalidACLInvestorError(
                "Only whitelisted investor can receive this action.",
                _to
            );
        }

        if(_amount % MINIMUM_DENOMINATION != 0) {
            revert InvalidValueError(
                "Amount must be a multiple of the minimum denomination."
            );
        }

        _mint(_to, _amount);
    }

    function setClose() external onlyOwner whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.MATURED){
        _setClose();
    }

    /**
        * @dev Update the interest rate for the next repayment. Needed only if the interest rate is floating.
        * @param _interstRate The new interest rate.
    */
    function updateInterestRateRepayment(uint256 _interstRate)
        external
        onlyOwner()
        whenLoanInterestType(LoanAssetFungibleLib.InterestRateTypeEnum.FLOATING)
        whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.LIVE)
    {
        if (currentRepaymentsIndex >= TOTAL_REPAYMENT_NUMBER) {
            revert InvalidValueError(
                "All repayments have been already defined."
            );
        }

        if (_interstRate == 0) {
            revert InvalidZeroValueError(
                "Interest rate must be greater than zero."
            );
        }

        _createCurrentRepayment(_interstRate);
    }

    function enableRepayment() external onlyOwner whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.LIVE) {

        if (currentRepaymentsIndex >= TOTAL_REPAYMENT_NUMBER) {
            revert InvalidValueError(
                "All repayments have been already defined."
            );
        }

        LoanAssetFungibleLib.RepaymentInfo storage repayment = repayments[currentRepaymentsIndex];

        if (repayment.repaymentType != LoanAssetFungibleLib.RepaymentTypeEnum.NORMAL) {
            revert InvalidRepaymentTypeError(
                "Repayment must be a normal repayment."
            );
        }

        _enableRepayment(repayment);
    }

    function _enableRepayment(LoanAssetFungibleLib.RepaymentInfo storage _repayment) internal {

        if (_repayment.status != LoanAssetFungibleLib.RepaymentStatusEnum.INITIALIZED) {
            revert InvalidRepaymentStatusError(
                "Repayment must be initialized.",
                currentRepaymentsIndex
            );
        }

        _repayment.status = LoanAssetFungibleLib.RepaymentStatusEnum.ENABLED;
    }

    function payRepayment(uint256 _amount) onlyBorrower() external whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.LIVE) {

        LoanAssetFungibleLib.RepaymentInfo storage repayment = repayments[currentRepaymentsIndex];

        if(repayment.repaymentType == LoanAssetFungibleLib.RepaymentTypeEnum.PRINCIPAL) {
            revert InvalidRepaymentTypeError(
                "Repayment must be a normal repayment."
            );
        }

       _executeRepayment(repayment, _amount);

       emit PrincipalPaidEvent(msg.sender, _amount);
    }

    function distributeInterest() external onlyOwner() whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.LIVE) {
        LoanAssetFungibleLib.RepaymentInfo memory repayment = repayments[currentRepaymentsIndex];

        if(repayment.repaymentType == LoanAssetFungibleLib.RepaymentTypeEnum.PRINCIPAL) {
            revert InvalidRepaymentTypeError(
                "Repayment must be a normal repayment."
            );
        }

        if(repayment.status != LoanAssetFungibleLib.RepaymentStatusEnum.PAID) {
            revert InvalidRepaymentStatusError(
                "Repayment must be paid.",
                currentRepaymentsIndex
            );
        }

        currentRepaymentsIndex++;

        // per each investor, calculate the interest proportional to the amount deposited and send PAYMENTAMOUNT to the investor
        // the last investor will receive the rest of the division (for now)
        // TODO manage rest of division: send the rest to owner? to last investor? leave in the sc?
        uint256 lastInvestorIndex = investors.length - 1;
        uint256 totalAmountRepayment = repayment.interestAmount + repayment.principalAmount;
        uint256 totalDistributed = 0;
        bool success;
        for (uint256 i = 0; i < lastInvestorIndex; ) {
            address investor = investors[i];
            uint256 interestAmount = (balanceOf(investor) * totalAmountRepayment) / _totalDeposited;

            success = PAYMENT_TOKEN.transfer(investor, interestAmount);
            if(!success) {
                revert TransferERC20Error("Error during the transfer of the funds.");
            }
            totalDistributed += interestAmount;
            unchecked {
                i++;
            }
        }
        // last investor
        uint256 lastInterestAmount = totalAmountRepayment - totalDistributed;
        address lastInvestor = investors[lastInvestorIndex];

        success = PAYMENT_TOKEN.transfer(lastInvestor, lastInterestAmount);
        if(!success) {
            revert TransferERC20Error("Error during the transfer of the funds.");
        }
        //TODO maybe need events?
    }

    function setMatured() external onlyOwner() whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.LIVE) {
        // last repayment is TOTAL_REPAYMENT_NUMBER - 1, and it is the principal repayment.
        // You can pay it only after all the normal repayments and when the loan is matured
        uint256 currentIndex = currentRepaymentsIndex;
        if(currentIndex != TOTAL_REPAYMENT_NUMBER - 1) {
            revert InvalidValueError(
                "All normal repayments must be paid."
            );
        }

        currentLoanStatus = LoanAssetFungibleLib.LoanStatusEnum.MATURED;

        // enable last repayment
        LoanAssetFungibleLib.RepaymentInfo storage repayment = repayments[currentIndex];
        _enableRepayment(repayment);

        emit LoanMaturedEvent();
    }

    function payPrincipal(uint256 _amount) external onlyBorrower() whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.MATURED) {
        LoanAssetFungibleLib.RepaymentInfo storage repayment = repayments[currentRepaymentsIndex];

        if(repayment.repaymentType != LoanAssetFungibleLib.RepaymentTypeEnum.PRINCIPAL) {
            revert InvalidRepaymentTypeError(
                "Repayment must be a principal repayment."
            );
        }

        _executeRepayment(repayment, _amount);
        _remainingLastRepayment = _amount; // needed for reedemTokens
    }

    function redeemTokens() external onlyWhitelistedInvestor() whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.MATURED) nonReentrant() {
        if (_numInvestorsActive == 0) {
            revert InvalidValueError("No active investors remaining.");
        }

        LoanAssetFungibleLib.RepaymentInfo memory lastRepayment = repayments[currentRepaymentsIndex];

        if(lastRepayment.status != LoanAssetFungibleLib.RepaymentStatusEnum.PAID) {
            revert InvalidRepaymentStatusError(
                "Last repayment must be paid.",
                currentRepaymentsIndex
            );
        }
        uint256 amountHold = balanceOf(msg.sender);
        if(amountHold == 0) {
            revert InvalidZeroValueError(
                "Amount must be greater than zero."
            );
        }

        uint256 totalAmountRepayment = lastRepayment.interestAmount + lastRepayment.principalAmount;
        uint256 amountToPayToInvestor;

        if (_numInvestorsActive == 1) {
        // last investor: send all the remaining balance
            // Note: Ensure that the contract's balance only includes legitimate repayments to avoid discrepancies.
            amountToPayToInvestor = _remainingLastRepayment;
        } else {
        // other investors: send the proportional amount
            amountToPayToInvestor = (amountHold * totalAmountRepayment) / _totalDeposited;
            _remainingLastRepayment -= amountToPayToInvestor;
        }

        _numInvestorsActive--;

        _burn(msg.sender, amountHold);
        bool success = PAYMENT_TOKEN.transfer(msg.sender, amountToPayToInvestor);
        if(!success) {
            revert TransferERC20Error("Error during the transfer of the funds.");
        }
    }

    function _executeRepayment(LoanAssetFungibleLib.RepaymentInfo storage repayment, uint256 _amount) internal {
        if (repayment.status != LoanAssetFungibleLib.RepaymentStatusEnum.ENABLED) {
            revert InvalidRepaymentStatusError(
                "Repayment must be enabled.",
                 currentRepaymentsIndex
            );
        }

        if (_amount == 0) {
            revert InvalidZeroValueError(
                "Amount must be greater than zero."
            );
        }

        uint256 principalPaid = repayment.principalAmount;
        uint256 calculatedAmount = repayment.interestAmount + principalPaid;

        if (_amount != calculatedAmount) {
            revert InvalidValueError(
                "Amount must be equal to the calculated amount."
            );
        }

        borrowerOutstandingPrincipalAmount -= principalPaid;
        repayment.status = LoanAssetFungibleLib.RepaymentStatusEnum.PAID;
        // NB: needed an approve before by borrower
        bool success = PAYMENT_TOKEN.transferFrom(msg.sender, address(this), _amount);
        if(!success) {
            revert TransferERC20Error("Error during the transfer of the funds.");
        }
    }

     function _calculateAmountRepayment(uint256 _interestRate, uint256 _principalOutstanding, uint256 _repaymentIndex)
        internal
        view
        returns (uint256 interestAmount, uint256 principalAmount, LoanAssetFungibleLib.RepaymentTypeEnum repaymentType)
    {

        uint256 totalRepaymentNumber = TOTAL_REPAYMENT_NUMBER; //gas saving
        uint256 lastRepaymentIndex = totalRepaymentNumber - 1; //gas saving
        uint256 remainingRepaymentNumber = lastRepaymentIndex - _repaymentIndex; // needed for italian amortization

        // determine the repayment type
        repaymentType = LoanAssetFungibleLib.RepaymentTypeEnum.NORMAL;
        if(_repaymentIndex == lastRepaymentIndex) {
            repaymentType = LoanAssetFungibleLib.RepaymentTypeEnum.PRINCIPAL;
        }

        // calculate the interest amount
        uint256 interestMatured = _calculateInterest(_interestRate, _principalOutstanding);

        // calculate the principal amount
        if(LOAN_TYPE == LoanAssetFungibleLib.LoanTypeEnum.BULLET) {
            interestAmount = interestMatured;
            // if last repayment, the principal amount is the outstanding principal amount (bullet payment)
            if(_repaymentIndex == lastRepaymentIndex) {
                principalAmount = _principalOutstanding;
            }
        } else if (LOAN_TYPE == LoanAssetFungibleLib.LoanTypeEnum.AMORTIZED) {
            // italian amortization
            principalAmount = _principalOutstanding / remainingRepaymentNumber;
        }

        return (interestAmount, principalAmount, repaymentType);
    }


    function _calculateInterest(uint256 _interestRate, uint256 _principalOutstanding) internal pure returns (uint256) {
        return (_interestRate * _principalOutstanding) / 10_000;
    }


    function _createCurrentRepayment(uint256 _interestRate) internal {
        uint256 repaymentIndex = currentRepaymentsIndex;
        LoanAssetFungibleLib.RepaymentInfo storage repayment = repayments[repaymentIndex];
        if (repayment.status != LoanAssetFungibleLib.RepaymentStatusEnum.NOT_ALREADY_DEFINED) {
            revert InvalidRepaymentStatusError(
                "Repayment must be not already defined.",
                repaymentIndex
            );
        }

        (uint256 interestAmount, uint256 principalAmount, LoanAssetFungibleLib.RepaymentTypeEnum repaymentType) = _calculateAmountRepayment(
            _interestRate, borrowerOutstandingPrincipalAmount, repaymentIndex
        );

        repayment.interestRate = _interestRate;
        repayment.status = LoanAssetFungibleLib.RepaymentStatusEnum.INITIALIZED;
        repayment.interestAmount = interestAmount;
        repayment.principalAmount = principalAmount;
        repayment.repaymentType = repaymentType;
    }

    function _whitelistInvestor(address _investor) internal {
        if (_investor == address(0)) {
            revert ZeroAddressError(
                "Investor address must be different from 0."
            );
        }
        if (investorsInfo[_investor].isWhitelisted) {
            revert InvestorAlreadyWhitelistedError(
                "Investor is already whitelisted.",
                _investor
            );
        }
        investorsInfo[_investor].isWhitelisted = true;
        investors.push(_investor);

        //TODO emit event needed?
    }

    function _unwhitelistInvestor(address _investor) internal {
        if (_investor == address(0)) {
            revert ZeroAddressError(
                "Investor address must be different from 0."
            );
        }
        if (!investorsInfo[_investor].isWhitelisted) {
            revert InvestorNotWhitelistedError(
                "Investor is not whitelisted.",
                _investor
            );
        }
        investorsInfo[_investor].isWhitelisted = false;
        uint256 investorsLength = investors.length;
        for (uint256 i = 0; i < investorsLength; i++) {
            if (investors[i] == _investor) {
                // swap the last element with the element to remove
                investors[i] = investors[investorsLength - 1];
                investors.pop();
                break;
            }
        }
        //TODO emit event needed?
    }

    function _depositFunds(address _from, uint256 _amount) internal whenLoanStatus(LoanAssetFungibleLib.LoanStatusEnum.INVESTOR_PERIOD) {
        if (_amount % MINIMUM_DENOMINATION != 0) {
            revert InvalidValueError(
                "Amount must be a multiple of the minimum denomination."
            );
        }
        // other checks to do?

        // if the investor is not already in the list, add it. Maybe an investor can deposit multiple times
        if(investorsInfo[_from].amountDeposited == 0) {
            _numInvestorsActive++;
        }
        investorsInfo[_from].amountDeposited += _amount;
        _totalDeposited += _amount;

        bool success = PAYMENT_TOKEN.transferFrom(_from, address(this), _amount);
        if(!success) {
            revert TransferERC20Error("Error during the transfer of the funds.");
        }

        emit FundsDepositedEvent(_from, _amount);
    }

    function _setClose() internal onlyOwner(){
        currentLoanStatus = LoanAssetFungibleLib.LoanStatusEnum.CLOSED;

        emit LoanClosedEvent();
    }

    function _distributeLoanTokens() internal {
        uint256 investorsLength = investors.length;
            for (uint256 _investorIndex = 0; _investorIndex < investorsLength; ) {
                address investor = investors[_investorIndex];
                mint(investor, investorsInfo[investor].amountDeposited);
                unchecked {
                    _investorIndex++;
                }
            }
    }

    function _refundInvestors() internal {
        uint256 investorsLength = investors.length;
        for(uint256 investorIndex = 0; investorIndex < investorsLength; ) {
                _refundInvestor(investorIndex);
                
                unchecked {
                    investorIndex++;
                }
        }
    }

    function _refundInvestor(uint256 _investorIndex) private {
        address investor = investors[_investorIndex];

        uint256 amount = investorsInfo[investor].amountDeposited;
        investorsInfo[investor].amountDeposited = 0;

        bool success = PAYMENT_TOKEN.transfer(investor, amount);
        if(!success) {
            revert TransferERC20Error("Error during the transfer of the funds.");
        }
    }
}
