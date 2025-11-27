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
- **Smart Contracts:** Solidity
- **Development Framework:** Foundry
- **Dependencies:** OpenZeppelin Contracts
- **Network:** EduChain

## Setup
To set up the project locally, clone the repository and install the dependencies.

1.  **Clone the repository:**
    ```sh
    git clone <YOUR_REPOSITORY_URL>
    cd salary-ewa
    ```

2.  **Install dependencies:**
    This project uses Foundry's library management. `forge-std` and `openzeppelin-contracts` are included as Git submodules.
    ```sh
    forge install
    ```

3.  **Run tests:**
    Execute the test suite to ensure all contracts are functioning correctly.
    ```sh
    forge test
    ```

## Deployment
The contracts are deployed on the EduChain network.

-   **Network Name:** EduChain
-   **RPC URL:** `https://rpc.open-campus-codex.gelato.digital/`
-   **Block Explorer:** `https://blockscout.com/`

### Contract Addresses
-   **PhiiCoin (Token) Address:** `0xe76808bbc4271c3d7bd6bc9873998d2099db3eda`
    -   [View on Blockscout](https://blockscout.com/address/0xe76808bbc4271c3d7bd6bc9873998d2099db3eda)
-   **SalaryEWA (Payroll) Address:** `[DEPLOYED_PAYROLL_ADDRESS]`
    -   **Note:** The deployment script has been updated to include the `SalaryEWA` contract. Run the deployment command below and replace the placeholder with the new address.

### Deployment Command
To deploy the contracts, set your `PRIVATE_KEY` in a `.env` file and run the deployment script with Forge:
```sh
# Make sure PRIVATE_KEY is set in your environment or a .env file
forge script script/DeployToken.s.sol --rpc-url educhain --broadcast
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