// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LoanAssetFungibleLib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILoanAssetFungible {
    // #################################### //
    // ############## ERRORS ############## //
    // #################################### //
    error ZeroAddressError(string err);
    error InvestorAlreadyWhitelistedError(string err, address investor);
    error InvalidACLOwnerError(string err, address caller);
    error InvalidACLBorrowerError(string err, address caller);
    error InvalidACLInvestorError(string err, address caller);
    error ReentrancyGuardError(string err);
    error PausedError(string err);
    error InvalidEmptyValueError(string err);
    error InvalidValueError(string err);
    error InvalidMathRestrictionStartMaturityDateError(
        string err,
        uint256 startDate,
        uint256 maturityDate
    );
    error InvalidDateError(
        string err,
        uint256 currentBlockTime,
        uint256 dateToCompare
    );
    error InvalidZeroValueError(string err);
    error InvalidZeroLenghtError(string err);

    error InvalidLengthInterestRateForRepaymentDateError(
        string err,
        uint256 interestRatesLength,
        uint256 repaymentDatesLength
    );
    error InvalidMathRestrictionSharesLenderError(
        string err,
        uint256 shares,
        uint256 totalShares
    );
    error InvalidMathRestrictionSharesBorrowerError(
        string err,
        uint256 shares,
        uint256 totalShares
    );
    error InvalidValueInterestRateTypeError(
        string err,
        LoanAssetFungibleLib.InterestRateTypeEnum currentInterestRateType,
        LoanAssetFungibleLib.InterestRateTypeEnum expectedInterestRateType
    );
    error InvalidValueLoanTypeError(
        string err,
        LoanAssetFungibleLib.LoanTypeEnum loanType
    );
    error InvalidValueLoanStatusError(
        string err,
        LoanAssetFungibleLib.LoanStatusEnum currentLoanStatus,
        LoanAssetFungibleLib.LoanStatusEnum expectedLoanStatus
    );
    error InvalidLenghtInterestRateForBorrowerError(
        string err,
        uint256 interestRate,
        uint256 borrowers
    );
    error InvalidValueRepaymentIndexError(
        string err,
        uint256 expectedRepaymentIndex,
        uint256 repaymentIndex
    );

    error InsufficientFundsError(string err);
    error InvalidTransferError(string err, address to, uint256 amount);
    error InvalidRepaymentStatusError(
        string err,
        address borrower,
        uint256 repaymentIndex,
        LoanAssetFungibleLib.RepaymentStatusEnum currentBorrowerStatus,
        LoanAssetFungibleLib.RepaymentStatusEnum expectedBorrowerStatus
    );

    error InvalidAmountToFundError(
        string err,
        uint256 amountToFund,
        uint256 amountSent
    );

    error InvalidAmountRepayFromAllBorrowersError(
        string err,
        address borrower,
        uint256 currentBorrowerStatus,
        uint256 expectedBorrowerStatus
    );

    error UnknownValueInterestRateTypeError(
        string err,
        LoanAssetFungibleLib.InterestRateTypeEnum interestRateType
    );

    // #################################### //
    // ############### EVENT ############## //
    // #################################### //

    event FundsDepositedEvent(address indexed sender, uint256 amount);
    event FundsWithdrawnEvent(address indexed sender, uint256 amount);

    event LoanTokenizedEvent(
        bytes32 name,
        address indexed owner,
        uint256 totalAmount
    );

    event LoanFundedEvent(
        address indexed lender,
        uint256 amount,
        uint256 totalAmount
    );

    event LoanStartedEvent();

    event EnableRepaymentEvent(
        address indexed borrower,
        uint256 repaymentIndex
    );

    event RepaymentPaidEvent(
        address indexed borrower,
        uint256 repaymentAmount,
        uint256 repaymentNumber
    );

    event UpdateInterestRateAndRepaymentsEvent(uint256[] interestRates);

    event LoanMaturedEvent();
    event LoanClosedEvent();

    event LoanRepaidEvent(address indexed borrower, uint256 repaymentAmount);

    // ##################################### //
    // ############### VIEW ################ //
    // ##################################### //

    function whitelistInvestors(address[] calldata investors) external;
    function depositFunds(uint256 amount) external;
}
