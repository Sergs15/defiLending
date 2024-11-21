// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IDefiLending {

    /// Structs
    struct Collateral {
        address tokenAddress;
        uint256 tokenAmount;
    }

    // Errors
    error CollateralIsZero();
    error AmountIsZero();
    error InsufficientCollateral();
    error RepaymentExceedsLoanBalance();
    error NoOutstandingLoans();
    error CollateralExceedsLoanLimit();
    error LinkTransferFailed();
    error TransferFailed();
    error CollateralAddressNotAllowed();
    error UserDoesNotHaveAnyLoan(address user);
    error MoneyOnLoanIsGreaterThanCollateral();
    error CollateralAmountNotEnough();
    error LoanAmountIsGreaterThanUsersDebt();
    error NotValidAddress();

    // External Functions
    function depositCollateralAndBorrow(Collateral calldata collateral, uint256 loanAmount) external payable;

    function depositCollateral(Collateral calldata collateral) external payable;

    function borrow(uint256 loanAmount) external payable;

    function repayLoan(uint256 repaymentAmount) external payable;

    function repayFullLoanAndWithdrawCollateral() external payable;

    function withdrawCollateral(Collateral calldata collateral) external payable;

    function checkLiquidations() external;

    function executeLiquidationForUser(address user) external;

    function getCollateralsByUser(address user) external view returns (uint256);

    function getTotalMoneyOnLoanByUser(address user) external view returns (uint256);

    function recalculateLoanInterest() external;

    function getLoanInterest() external view returns (uint256);

    function setLoanInterest(uint256 newLoanInterest) external;

    // Events
    event CollateralDeposited(address indexed user, address token, uint256 amount);
    event LoanIssued(address indexed user, uint256 loanAmount);
    event LoanRepaid(address indexed user, uint256 amountRepaid);
    event LoanFullyRepaid(address indexed user);
    event CollateralWithdrawn(address indexed user, address token, uint256 amount);
    event LoanLiquidated(address user);
    event LoanInterestRecalculatedForUser(address user, uint256 loanAmount);

}
