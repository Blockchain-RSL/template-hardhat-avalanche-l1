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
    error InvestorNotWhitelistedError(string err, address investor);
    error InvalidACLOwnerError(string err, address caller);
    error InvalidACLBorrowerError(string err, address caller);
    error InvalidACLInvestorError(string err, address caller);
    error ReentrancyGuardError(string err);
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
   
    error InvalidValueLoanStatusError(
        string err,
        LoanAssetFungibleLib.LoanStatusEnum currentLoanStatus,
        LoanAssetFungibleLib.LoanStatusEnum expectedLoanStatus
    );

    error InsufficientGoalAmountError(string err);
    error InvalidRepaymentStatusError(
        string err,
        uint256 repaymentIndex
    );

    error InvalidValueInterestRateTypeError(
        string err,
        LoanAssetFungibleLib.InterestRateTypeEnum currentInterestRateType,
        LoanAssetFungibleLib.InterestRateTypeEnum expectedInterestRateType
    );

    error InvalidRepaymentTypeError(
        string err
    );

    error TransferERC20Error(string err);

    // #################################### //
    // ############### EVENT ############## //
    // #################################### //

    event FundsDepositedEvent(address indexed sender, uint256 amount);

    event LoanTokenizedEvent(
        bytes32 name,
        address indexed owner,
        uint256 totalAmount
    );

    event RepaymentPaidEvent(
        address indexed borrower,
        uint256 repaymentAmount,
        uint256 repaymentNumber
    );

    event PrincipalPaidEvent(
        address indexed borrower,
        uint256 repaymentAmount
    );

    event InterestPaidEvent(
        address indexed borrower,
        uint256 interestAmount,
        uint256 repaymentNumber
    );

    event LoanMaturedEvent();
    event LoanInvestorPeriodEvent();
    event LoanLiveEvent();
    event LoanClosedEvent();

    event InvestorWhitelistedEvent(
        address indexed investor
    );

    event InvestorUnwhitelistedEvent(
        address indexed investor
    );

    // ##################################### //
    // ############### VIEW ################ //
    // ##################################### //

    function whitelistInvestors(address[] calldata investors) external;
    function depositFunds(uint256 amount) external;
}
