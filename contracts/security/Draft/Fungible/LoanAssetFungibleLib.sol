// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
library LoanAssetFungibleLib {
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
        INVESTOR_PERIOD,
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
        uint256 borrowerOustandingAmount;
        uint256[] interestRates;
        uint256[] repaymentsDates;
    }

    struct RepaymentInfo {
        uint256 paymentDate;
        uint256 interestRate;
        RepaymentStatusEnum status;
    }
}
