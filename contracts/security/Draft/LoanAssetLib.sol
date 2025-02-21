// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
library LoanAssetLib {
    // ##################################### //
    // ############### ENUM ################ //
    // ##################################### //
    enum LoanTypeEnum {
        BULLET,
        AMORTIZED
    }

    enum InterestRateTypeEnum {
        FIXED,
        FLOATING
    }

    enum LoanStatusEnum {
        PRELIMINARY,
        LIVE,
        MATURED,
        CLOSED
    }

    enum RepaymentStatusEnum {
        NOT_ALREADY_DEFINED,
        INITIALIZED,
        ENABLED,
        PAID
    }

    enum BorrowerStatusEnum {
        DISABLED,
        INITIALIZED,
        ENABLED,
        REPAID,
        DEFAULTED,
        ANTICIPATED
    }

    enum LenderStatusEnum {
        DISABLED,
        ENABLED,
        DEPOSITED,
        REFUNDED
    }

    // ##################################### //
    // ############### STRUCT ############## //
    // ##################################### //

    struct LoanAnagInfo {
        bytes32 name;
        bytes32 issuanceCountry;
        bytes32 currency;
        LoanTypeEnum loanType;
        InterestRateTypeEnum interestRateType;
        uint256 startDate;
        uint256 maturityDate;
    }

    struct LoanPaymentInfo {
        uint256 totalAmount;
        uint256 minimumDenomination;
        uint256[] spreadForBorrower;
        uint256[] interestRates;
        uint256[] repaymentsDates;
    }

    struct LoanParticipantInfo {
        address[] lenders;
        uint256[] lendersShares;
        address[] borrowers;
        uint256[] borrowersShares;
    }

    struct RepaymentInfo {
        uint256 paymentDate;
        uint256 interestRate;
        RepaymentStatusEnum status;
    }

    struct OutstandingInfo {
        uint256 outstandingPrincipalAmount;
        uint256 currentRepaymentIndex;
        uint256 anticipatedRepaymentAmount;
    }

    struct BorrowerInfo {
        BorrowerStatusEnum status;
        uint256 shares;
        uint256 spread;
    }

    struct LenderInfo {
        LenderStatusEnum status;
        uint256 shares;
    }
}
