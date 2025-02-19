node ./scripts/HLC/resetScInfo.js

call npx hardhat run ./scripts/NativeTokenICKT/0_transfer_token.js

call npx hardhat run ./scripts/draft/LoanFixed/0_issue_loan.js
call npx hardhat run ./scripts/draft/LoanFixed/1_lenders_deposit.js
call npx hardhat run ./scripts/draft/LoanFixed/2_start_loan.js
call npx hardhat run ./scripts/draft/LoanFixed/3_repayments.js
call npx hardhat run ./scripts/draft/LoanFixed/4_mature_loan.js
call npx hardhat run ./scripts/draft/LoanFixed/5_principal.js
call npx hardhat run ./scripts/draft/LoanFixed/6_close_loan.js
call npx hardhat run ./scripts/draft/LoanFixed/7_withdraw.js