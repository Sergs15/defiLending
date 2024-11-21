# DefiLending

**DefiLending** is a decentralized finance (DeFi) smart contract system that allows users to deposit cryptocurrency as collateral, borrow tokens, and repay loans. It accepts LINK tokens as collateral and returns its own token, BTZ Token, in exchange.

## Features
- **Collateralized Lending:** Users can deposit supported tokens as collateral to borrow funds.
- **Dynamic Loan Interest:** Adjustable loan interest rates controlled by the contract owner.
- **Price Feeds:** Uses external price feeds to calculate loan-to-collateral ratios.
- **Collateral Management:** Deposit, withdraw, and liquidate collateral.
- **Security Features:**
  - OnlyOwner modifiers for admin operations.
  - NonReentrant protection.
  - Validations for all input parameters.
  
## Technology Stack
- **Solidity** for smart contract development.
- **Hardhat** for testing, deployment, and development.
- **OpenZeppelin** for reusable security-focused smart contract modules.
- **Ethers.js** for interacting with the Ethereum blockchain in scripts and tests.
- **Chai and Mocha** for writing and executing unit tests.
- **TypeScript** for robust scripting and testing.

Future Enhancements

Add support for multiple collateral token types.
Integrate Chainlink price feeds for real-world data.
Build a frontend for user interaction.
Implement advanced liquidation mechanisms.
License

This project is licensed under the MIT License.

