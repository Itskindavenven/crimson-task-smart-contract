# Mancer Crimson Proof of Skill – Bonaventura Octavito Cahyawan

## Overview
This project is an implementation of an **Earned Wage Access (EWA) Payroll System** for the Mancer Crimson Proof of Skill Smart Contract track.

It features a Solidity smart contract, `SalaryEWA.sol`, that allows an employer to pay employees in a continuous stream. Employees can withdraw their accrued salary at any time, request advances, and are paid out in a designated ERC20 token. The system is built using the Foundry framework and follows modern security best practices.

## Features
- **Continuous Salary Accrual:** Employee salaries are streamed on a per-second basis, calculated from their monthly salary.
- **On-Demand Withdrawals:** Employees can withdraw their net earned salary at any point during the pay period.
- **Salary Advances:** Employees can request an advance of up to 50% of their currently available earnings, limited to one advance per pay period.
- **Employer Fund Management:** The employer can fund the contract with payroll tokens and refund excess funds that are not locked for payment.
- **Pay Period Settlement:** The employer can settle an employee's pay period, which automatically repays any outstanding advances and transfers the remaining salary.
- **Administrative Controls:** The contract owner (employer) has exclusive rights to register/update employees and manage funds.
- **Security-First Design:** Implements Reentrancy Guard, Pausable functionality, SafeERC20, and a Checks-Effects-Interactions pattern.

## Stack
- **Smart Contracts:** Solidity ^0.8.30
- **Development Framework:** Foundry
- **Dependencies:** OpenZeppelin Contracts v5.1.0
- **Network:** Base Sepolia Testnet
- **Testing:** Foundry Test Suite (102 comprehensive tests)

## Setup
To set up the project locally, clone the repository and install the dependencies.

1.  **Clone the repository:**
    ```sh
    git clone <YOUR_REPOSITORY_URL>
    cd crimson-task-smart-contract
    ```

2.  **Install dependencies:**
    This project uses Foundry's library management. `forge-std` and `openzeppelin-contracts` are included as Git submodules.
    ```sh
    forge install
    ```

3.  **Run tests:**
    Execute the comprehensive test suite to ensure all contracts are functioning correctly.
    ```sh
    forge test
    ```
    
    **Test Coverage:**
    - 102 tests across 7 test files
    - 100% coverage of must-have requirements
    - 100% coverage of security requirements

## Deployment

> **Note:** This project was initially planned for deployment on EduChain testnet. However, due to RPC connectivity issues and network instability on EduChain, we switched to **Base Sepolia testnet** for a more reliable deployment experience.

The contracts are deployed on the **Base Sepolia** network.

### Network Information

| Parameter | Value |
|-----------|-------|
| **Network Name** | Base Sepolia |
| **Chain ID** | 84532 |
| **Currency** | ETH |
| **RPC URL** | `https://base-sepolia-rpc.publicnode.com` |
| **Block Explorer** | https://sepolia.basescan.org/ |
| **Faucet** | https://www.alchemy.com/faucets/base-sepolia |

### Contract Addresses

✅ **Deployed & Verified on Base Sepolia** (Block: 35402174)

-   **PhiiCoin (Token):** `0x6eAc85faD7faED5E44853edFA45246704795BeAc` ✅ Verified
    -   [View Contract](https://sepolia.basescan.org/address/0x6eAc85faD7faED5E44853edFA45246704795BeAc)
    -   [View Source Code](https://sepolia.basescan.org/address/0x6eAc85faD7faED5E44853edFA45246704795BeAc#code)
    
-   **SalaryEWA (Payroll):** `0xD875b836C85047C4eA4584E8B74e7eefE1ccC1bc` ✅ Verified
    -   [View Contract](https://sepolia.basescan.org/address/0xD875b836C85047C4eA4584E8B74e7eefE1ccC1bc)
    -   [View Source Code](https://sepolia.basescan.org/address/0xD875b836C85047C4eA4584E8B74e7eefE1ccC1bc#code)
    
-   **Deployer/Owner:** `0x906B34db1a8DD333ff9a84255e4AEc13C054f120`
    -   [View Address](https://sepolia.basescan.org/address/0x906B34db1a8DD333ff9a84255e4AEc13C054f120)

### Deployment Instructions

1. **Setup Environment:**
   ```sh
   cp .env.example .env
   # Edit .env and add your PRIVATE_KEY
   ```

2. **Get Testnet ETH:**
   - Visit: https://www.alchemy.com/faucets/base-sepolia
   - Request ETH for your wallet address

3. **Deploy Contracts:**
   ```sh
   forge script script/DeployToken.s.sol:DeployToken \
       --rpc-url base_sepolia \
       --broadcast \
       -vvvv
   ```

4. **Verify Contracts (Optional):**
   ```sh
   # Get Basescan API key from: https://basescan.org/myapikey
   # Add to .env: BASESCAN_API_KEY=your_key
   
   forge verify-contract <CONTRACT_ADDRESS> \
       src/ContractName.sol:ContractName \
       --chain-id 84532 \
       --watch
   ```

For detailed deployment instructions, see [BASE_SEPOLIA_DEPLOYMENT.md](./BASE_SEPOLIA_DEPLOYMENT.md)

## Testing

This project includes a comprehensive test suite with **102 tests** covering all requirements:

### Test Files

- **PayrollSystem.t.sol** (27 tests) - Core payroll functionality
- **EWA.t.sol** (16 tests) - Earned Wage Access features
- **Accounting.t.sol** (14 tests) - Balance tracking and accounting
- **Security.t.sol** (35 tests) - Security requirements and access control
- **Admin.t.sol** (5 tests) - Administrative functions
- **Accrual.t.sol** (3 tests) - Salary accrual mechanics
- **SalaryEWA.t.sol** (2 tests) - Integration tests

### Running Tests

```sh
# Run all tests
forge test

# Run with verbosity
forge test -vv

# Run specific test file
forge test --match-path test/PayrollSystem.t.sol -vv

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```

### Test Results

```
Total Test Suites: 7
Total Tests: 102
✅ Passed: 102
❌ Failed: 0
⏭️ Skipped: 0
```

## Why Base Sepolia Instead of EduChain?

While EduChain was the original target network for this project, we encountered several technical challenges:

1. **RPC Connectivity Issues:** Frequent timeouts and connection errors with EduChain RPC endpoints
2. **Network Instability:** Inconsistent block production and transaction processing
3. **Limited Faucet Access:** Difficulty obtaining testnet tokens for deployment
4. **Chain ID Confusion:** Multiple conflicting chain IDs in documentation

**Base Sepolia Advantages:**
- ✅ Stable and reliable RPC endpoints
- ✅ Easy access to testnet ETH via multiple faucets
- ✅ Excellent block explorer (Basescan)
- ✅ Active developer community and support
- ✅ Well-documented and maintained by Coinbase

The smart contracts are **chain-agnostic** and can be deployed on any EVM-compatible network, including EduChain when its infrastructure stabilizes.

## Project Structure

```
crimson-task-smart-contract/
├── src/
│   ├── PhiiCoin.sol          # ERC20 token contract
│   └── SalaryEWA.sol          # Main payroll contract
├── test/
│   ├── PayrollSystem.t.sol    # Payroll functionality tests
│   ├── EWA.t.sol              # EWA feature tests
│   ├── Accounting.t.sol       # Accounting tests
│   ├── Security.t.sol         # Security tests
│   ├── Admin.t.sol            # Admin tests
│   ├── Accrual.t.sol          # Accrual tests
│   └── SalaryEWA.t.sol        # Integration tests
├── script/
│   └── DeployToken.s.sol      # Deployment script
├── foundry.toml               # Foundry configuration
├── .env.example               # Environment template
└── README.md                  # This file
```

## Notes

### Challenges
A key challenge was designing a fair and secure fund management system. The employer needs the flexibility to refund excess capital, but the contract must guarantee that all earned salaries can be paid. The `_computeLockedAmount()` internal function solves this by creating a real-time accounting of all funds owed to employees, ensuring only truly "free" funds can be withdrawn by the owner.

### Design Decisions
-   **Per-Second Accrual:** A per-second streaming model was chosen over per-block accrual to make the system time-based and chain-agnostic. It provides a smooth and intuitive earnings stream for employees.
-   **One Advance Per Period:** The decision to limit advances to one per pay period simplifies the accounting logic and prevents potential abuse, while still providing employees with a powerful tool for liquidity. The 50% cap is a tuneable parameter that balances flexibility with risk.
-   **Explicit Settlement:** The `releaseSalary` function requires explicit action from the employer. This design gives the employer full control over the payroll cycle and ensures that the repayment of advances and the start of a new pay period are handled correctly in a single, atomic transaction.

### Trade-offs
-   **Gas Costs for Iteration:** The `_computeLockedAmount()` function iterates over the `employeeList` array. While efficient for a small-to-medium number of employees, this could become costly at a very large scale. For a system with thousands of employees, an alternative pattern (like requiring employees to "claim" their portion of locked funds) might be considered, though it would increase complexity.
-   **On-Chain Data Storage:** Storing all employee data on-chain increases transparency and trustlessness but also incurs higher gas costs for registration and updates compared to an off-chain or hybrid model. The current design prioritizes on-chain integrity for this proof-of-skill.

## License

MIT License

## Author

**Bonaventura Octavito Cahyawan**
- Mancer Crimson Proof of Skill - Smart Contract Track
- December 2025
