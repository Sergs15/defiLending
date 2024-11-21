// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IDefiLending.sol";
import "./PriceFeed.sol";
import "./BTZToken.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract DefiLending is IDefiLending, ReentrancyGuard, Ownable, Initializable {
    mapping(address user => uint256 tokenAmount) collateralsByUser;
    mapping(address user => uint256 totalMoneyOnLoan) totalMoneyOnLoanByUser;
    address[] collateralAddressesAllowed; //Only one collateral allowed for simplicity
    mapping(address user => uint256 index) userToIndex;
    address[] activeUsers;

    BTZToken btzToken;

    PriceFeed public priceFeed;

    uint256 loanInterest;
    uint256 collateralToLoanRate = 1; //For simplicity

    constructor() Ownable(_msgSender()) {
    }

    /// @notice Initialize the contract with the required addresses and parameters.
    /// @param _btzToken The address of the BTZToken contract.
    /// @param collateralToken The address of the initial allowed collateral token.
    /// @param priceFeedAddress The address of the price feed contract.
    /// @param _loanInterest The initial loan interest rate (percentage).
    function initialize(
        address _btzToken,
        address collateralToken,
        address priceFeedAddress,
        uint256 _loanInterest
    ) public initializer() onlyValidAddress(_btzToken) {
        btzToken = BTZToken(_btzToken);
        collateralAddressesAllowed.push(address(collateralToken));
        priceFeed = PriceFeed(priceFeedAddress);
        loanInterest = _loanInterest;
    }

    /// @notice Deposit collateral and take a loan in BTZ tokens.
    /// @param collateral The collateral information (address and amount).
    /// @param loanAmount The amount of BTZ tokens to borrow.
    function depositCollateralAndBorrow(
        Collateral calldata collateral,
        uint256 loanAmount
    )
        external
        payable
        onlyValidAmount(loanAmount)
        onlyValidCollateral(collateral)
        checkCollateralNotExceedsMoney(collateral.tokenAmount, loanAmount)
        nonReentrant
    {
        require(
            btzToken.transfer(_msgSender(), loanAmount),
            "LINK transfer failed"
        );

        IERC20 collateralToken = IERC20(collateral.tokenAddress);
        collateralToken.transferFrom(
            _msgSender(),
            address(this),
            collateral.tokenAmount
        );

        if (!userExists(_msgSender())) {
            addActiveUser(_msgSender());
        }
        collateralsByUser[_msgSender()] += collateral.tokenAmount;
        totalMoneyOnLoanByUser[_msgSender()] += loanAmount;

        emit LoanIssued(_msgSender(), loanAmount);
    }

    /// @notice Deposit collateral without borrowing any loan.
    /// @param collateral The collateral information (address and amount).
    function depositCollateral(
        Collateral calldata collateral
    ) external payable onlyValidCollateral(collateral) nonReentrant {
        IERC20 collateralToken = IERC20(collateral.tokenAddress);
        collateralToken.transferFrom(
            _msgSender(),
            address(this),
            collateral.tokenAmount
        );

        if (!userExists(_msgSender())) {
            addActiveUser(_msgSender());
        }
        collateralsByUser[_msgSender()] += collateral.tokenAmount;

        emit CollateralDeposited(
            _msgSender(),
            collateral.tokenAddress,
            collateral.tokenAmount
        );
    }

    /// @notice Borrow a loan in BTZ tokens without providing additional collateral.
    /// @param loanAmount The amount of BTZ tokens to borrow.
    function borrow(
        uint256 loanAmount
    ) external payable checkMoneyCanBeLend(loanAmount) nonReentrant {
        require(
            btzToken.transfer(_msgSender(), loanAmount),
            "BTZ transfer failed"
        );

        totalMoneyOnLoanByUser[_msgSender()] += loanAmount;

        emit LoanIssued(_msgSender(), loanAmount);
    }

    /// @notice Repay a part of the outstanding loan in BTZ tokens.
    /// @param loanAmount The amount of BTZ tokens to repay.
    function repayLoan(
        uint256 loanAmount
    )
        external
        payable
        onlyValidAmount(loanAmount)
        checkMoneyNotExceedsTotal(loanAmount)
        nonReentrant
    {
        require(
            btzToken.transferFrom(_msgSender(), address(this), loanAmount),
            "LINK transfer failed"
        );

        totalMoneyOnLoanByUser[_msgSender()] -= loanAmount;
        emit LoanRepaid(_msgSender(), loanAmount);

        if (totalMoneyOnLoanByUser[_msgSender()] == 0) {
            removeActiveUser(_msgSender());
            emit LoanFullyRepaid(_msgSender());
        }
    }

    /// @notice Repay the full outstanding loan and withdraw all deposited collateral.
    function repayFullLoanAndWithdrawCollateral()
        external
        payable
        onlyUsersWithLoans
        nonReentrant
    {
        require(
            btzToken.transferFrom(
                _msgSender(),
                address(this),
                totalMoneyOnLoanByUser[_msgSender()]
            ),
            "BTZ transfer failed"
        );
        for (uint256 i; i < collateralAddressesAllowed.length; i++) {
            IERC20 collateralToken = IERC20(collateralAddressesAllowed[i]);
            require(
                collateralToken.transfer(
                    _msgSender(),
                    collateralsByUser[_msgSender()]
                ),
                "Transfer failed"
            );
            uint256 tokenAmount = collateralsByUser[_msgSender()];
            collateralsByUser[_msgSender()] = 0;
            emit CollateralWithdrawn(
                _msgSender(),
                collateralAddressesAllowed[i],
                tokenAmount
            );
        }
        totalMoneyOnLoanByUser[_msgSender()] = 0;
        removeActiveUser(_msgSender());
        emit LoanFullyRepaid(_msgSender());
    }

    /// @notice Withdraw a portion of the collateral that is not locked by the loan.
    /// @param collateral The collateral information (address and amount).
    function withdrawCollateral(
        Collateral calldata collateral
    )
        external
        payable
        onlyValidCollateral(collateral)
        checkCollateralCanBeWithdrawn(collateral.tokenAmount)
        nonReentrant
    {
        IERC20 collateralToken = IERC20(collateral.tokenAddress);
        require(
            collateralToken.transfer(_msgSender(), collateral.tokenAmount),
            "Transfer failed"
        );

        collateralsByUser[_msgSender()] -= collateral.tokenAmount;

        emit CollateralWithdrawn(
            _msgSender(),
            collateral.tokenAddress,
            collateral.tokenAmount
        );
    }

    /// @notice Calculate the maximum loan amount based on the provided collateral amount.
    /// @param collateralAmount The amount of collateral to calculate the loan against.
    /// @return The maximum loan amount that can be borrowed.
    function calculateMaxLoanAmount(
        uint256 collateralAmount
    ) public view returns (uint256) {
        return getCollateralValue(collateralAmount) * collateralToLoanRate;
    }

    /// @notice Execute liquidation for a user whose loan-to-collateral ratio is too high.
    /// @param user The address of the user to be liquidated.
    function executeLiquidationForUser(
        address user
    ) public onlyValidAddress(user) onlyOwner {
        collateralsByUser[user] = 0;
        totalMoneyOnLoanByUser[user] = 0;
        removeActiveUser(user);
        emit LoanLiquidated(user);
    }

    /// @notice Check and execute liquidation for all users with unhealthy loan-to-collateral ratios.
    function checkLiquidations() external onlyOwner {
        uint256 arrayLength = activeUsers.length;
        for (uint256 i; i < arrayLength; i++) {
            if (
                getCollateralValue(collateralsByUser[activeUsers[i]]) <
                totalMoneyOnLoanByUser[activeUsers[i]]
            ) {
                executeLiquidationForUser(activeUsers[i]);
            }
        }
    }

    /// @notice Recalculate the loan interest for all users and update their outstanding debts.
    function recalculateLoanInterest() external onlyOwner {
        uint256 activeUsersLength = activeUsers.length;
        for (uint256 i; i < activeUsersLength; i++) {
            address user = activeUsers[i];
            uint256 currentLoan = totalMoneyOnLoanByUser[user];
            uint256 interest = (currentLoan * loanInterest) / 100;
            totalMoneyOnLoanByUser[user] += interest;
            emit LoanInterestRecalculatedForUser(
                activeUsers[i],
                totalMoneyOnLoanByUser[activeUsers[i]]
            );
        }
    }

    function getLoanInterest() external view onlyOwner returns (uint256) {
        return loanInterest;
    }

    function setLoanInterest(uint256 newLoanInterest) external onlyOwner {
        loanInterest = newLoanInterest;
    }

    function getCollateralsByUser(
        address user
    ) external view onlyOwner returns (uint256) {
        return collateralsByUser[user];
    }

    function getTotalMoneyOnLoanByUser(
        address user
    ) external view onlyOwner returns (uint256) {
        return totalMoneyOnLoanByUser[user];
    }

    function getCollateralValue(
        uint256 collateralAmount
    ) internal view returns (uint256) {
        // 1 USD = 1 BTZ
        return uint256(priceFeed.getLatestEthPriceInUSD()) * collateralAmount;
    }

    function addActiveUser(address user) internal {
        activeUsers.push(user);
        userToIndex[user] = activeUsers.length;
    }

    function userExists(address user) private view returns (bool) {
        if (totalMoneyOnLoanByUser[user] == 0 && collateralsByUser[user] == 0) {
            return false;
        }
        return true;
    }

    function removeActiveUser(address user) internal {
        if (userToIndex[user] == 0) {
            return; //already removed
        }

        uint256 userIndex = userToIndex[user] - 1;
        uint256 lastIndex = activeUsers.length - 1;

        userToIndex[activeUsers[lastIndex]] = userIndex;
        activeUsers[userIndex] = activeUsers[lastIndex];

        activeUsers.pop();

        userToIndex[user] = 0;
    }

    modifier checkCollateralCanBeWithdrawn(uint256 collateralAmount) {
        if (
            totalMoneyOnLoanByUser[_msgSender()] >
            calculateMaxLoanAmount(collateralAmount)
        ) {
            revert MoneyOnLoanIsGreaterThanCollateral();
        }
        _;
    }

    modifier checkMoneyCanBeLend(uint256 loanAmount) {
        if (
            calculateMaxLoanAmount(collateralsByUser[_msgSender()]) <
            loanAmount + totalMoneyOnLoanByUser[_msgSender()]
        ) {
            revert CollateralAmountNotEnough();
        }
        _;
    }

    modifier checkMoneyNotExceedsTotal(uint256 loanAmount) {
        if (loanAmount > totalMoneyOnLoanByUser[_msgSender()]) {
            revert LoanAmountIsGreaterThanUsersDebt();
        }
        _;
    }

    modifier checkCollateralNotExceedsMoney(
        uint256 tokenAmount,
        uint256 loanMoney
    ) {
        if (getCollateralValue(tokenAmount) < loanMoney) {
            revert CollateralAmountNotEnough();
        }
        _;
    }

    modifier onlyValidAmount(uint256 amount) {
        if (amount == 0) {
            revert AmountIsZero();
        }
        _;
    }

    modifier onlyValidCollateral(Collateral calldata collateral) {
        if (collateral.tokenAmount == 0) {
            revert CollateralIsZero();
        }
        bool isAllowed = false;
        for (uint256 i = 0; i < collateralAddressesAllowed.length; i++) {
            if (collateralAddressesAllowed[i] == collateral.tokenAddress) {
                isAllowed = true;
                break;
            }
        }
        require(isAllowed, "Collateral address not allowed");
        _;
    }

    modifier onlyUsersWithLoans() {
        if (totalMoneyOnLoanByUser[_msgSender()] <= 0) {
            revert UserDoesNotHaveAnyLoan(_msgSender());
        }
        _;
    }

    modifier onlyValidAddress(address address_) {
        if (address_ == address(0)) {
            revert NotValidAddress();
        }
        _;
    }
}
