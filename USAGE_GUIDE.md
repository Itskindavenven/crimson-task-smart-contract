# How to Interact with Salary EWA Smart Contracts

This guide explains how to read and write to the deployed smart contracts on Base Sepolia testnet.

## 📋 Contract Addresses

- **PhiiCoin (Token):** `0x6eAc85faD7faED5E44853edFA45246704795BeAc`
- **SalaryEWA (Payroll):** `0xD875b836C85047C4eA4584E8B74e7eefE1ccC1bc`
- **Network:** Base Sepolia (Chain ID: 84532)

---

## 🌐 Method 1: Using Basescan UI (Easiest)

### Reading Contract Data

1. **Open Contract on Basescan:**
   - PhiiCoin: https://sepolia.basescan.org/address/0x6eAc85faD7faED5E44853edFA45246704795BeAc#readContract
   - SalaryEWA: https://sepolia.basescan.org/address/0xD875b836C85047C4eA4584E8B74e7eefE1ccC1bc#readContract

2. **Click "Read Contract" tab**

3. **Available Read Functions:**

   **PhiiCoin (ERC20):**
   - `name()` - Returns "Phii Coin"
   - `symbol()` - Returns "PHII"
   - `totalSupply()` - Returns total supply (2,000,000 PHII)
   - `balanceOf(address)` - Check balance of any address
   - `allowance(owner, spender)` - Check token allowance

   **SalaryEWA (Payroll):**
   - `getEmployeeInfo(address)` - Get employee details (salary, accrued, available, etc.)
   - `employeesCount()` - Total number of employees
   - `employeeList(uint256)` - Get employee address by index
   - `token()` - Get token contract address
   - `payPeriodSeconds()` - Get pay period duration (30 days)
   - `totalFunded()` - Total amount funded
   - `totalWithdrawn()` - Total amount withdrawn
   - `totalRefunded()` - Total amount refunded

4. **Example - Check Employee Info:**
   - Click `getEmployeeInfo`
   - Enter employee address
   - Click "Query"
   - See: salary, active status, period start, accrued amount, etc.

### Writing to Contract

1. **Connect Wallet:**
   - Click "Connect to Web3" button on Basescan
   - Connect MetaMask (make sure you're on Base Sepolia network)

2. **Click "Write Contract" tab**

3. **Available Write Functions:**

   **Owner Functions (Only contract owner can call):**
   - `registerEmployee(address, uint256)` - Register new employee with monthly salary
   - `updateEmployee(address, uint256, bool)` - Update employee salary/status
   - `fund(uint256)` - Fund the payroll contract with tokens
   - `releaseSalary(address)` - Release salary for an employee (end of period)
   - `refund(uint256)` - Refund unused funds
   - `emergencyWithdraw(address, uint256)` - Emergency withdrawal
   - `pause()` - Pause contract operations
   - `unpause()` - Unpause contract

   **Employee Functions:**
   - `withdraw()` - Withdraw accrued salary
   - `requestAdvance(uint256)` - Request salary advance (max 50% of available)

4. **Example - Register Employee:**
   - Click `registerEmployee`
   - Enter employee address: `0x...`
   - Enter monthly salary: `1000000000000000000000` (1000 PHII in wei)
   - Click "Write"
   - Confirm transaction in MetaMask

---

## 💻 Method 2: Using Cast (Command Line)

### Setup

```bash
# Set RPC URL
export RPC_URL="https://base-sepolia-rpc.publicnode.com"

# Contract addresses
export PHII_COIN="0x6eAc85faD7faED5E44853edFA45246704795BeAc"
export SALARY_EWA="0xD875b836C85047C4eA4584E8B74e7eefE1ccC1bc"
```

### Reading Contract Data

```bash
# Check PhiiCoin total supply
cast call $PHII_COIN "totalSupply()" --rpc-url $RPC_URL

# Check balance of an address
cast call $PHII_COIN "balanceOf(address)(uint256)" 0xYourAddress --rpc-url $RPC_URL

# Get employee info
cast call $SALARY_EWA "getEmployeeInfo(address)" 0xEmployeeAddress --rpc-url $RPC_URL

# Get total employees
cast call $SALARY_EWA "employeesCount()" --rpc-url $RPC_URL

# Get pay period
cast call $SALARY_EWA "payPeriodSeconds()" --rpc-url $RPC_URL

# Get total funded
cast call $SALARY_EWA "totalFunded()" --rpc-url $RPC_URL
```

### Writing to Contract

```bash
# Register employee (Owner only)
cast send $SALARY_EWA \
    "registerEmployee(address,uint256)" \
    0xEmployeeAddress \
    1000000000000000000000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY

# Fund payroll (Owner only)
# First approve tokens
cast send $PHII_COIN \
    "approve(address,uint256)" \
    $SALARY_EWA \
    10000000000000000000000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY

# Then fund
cast send $SALARY_EWA \
    "fund(uint256)" \
    10000000000000000000000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY

# Employee withdraw
cast send $SALARY_EWA \
    "withdraw()" \
    --rpc-url $RPC_URL \
    --private-key $EMPLOYEE_PRIVATE_KEY

# Request advance (Employee)
cast send $SALARY_EWA \
    "requestAdvance(uint256)" \
    500000000000000000000 \
    --rpc-url $RPC_URL \
    --private-key $EMPLOYEE_PRIVATE_KEY

# Release salary (Owner only)
cast send $SALARY_EWA \
    "releaseSalary(address)" \
    0xEmployeeAddress \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY
```

---

## 🦊 Method 3: Using MetaMask + Web3.js/Ethers.js

### Setup MetaMask

1. **Add Base Sepolia Network:**
   - Network Name: Base Sepolia
   - RPC URL: `https://sepolia.base.org`
   - Chain ID: `84532`
   - Currency: ETH
   - Block Explorer: `https://sepolia.basescan.org`

2. **Add PHII Token:**
   - Open MetaMask
   - Click "Import tokens"
   - Token Address: `0x6eAc85faD7faED5E44853edFA45246704795BeAc`
   - Symbol: PHII
   - Decimals: 18

### Using Ethers.js (JavaScript)

```javascript
const { ethers } = require('ethers');

// Setup
const provider = new ethers.JsonRpcProvider('https://sepolia.base.org');
const wallet = new ethers.Wallet('YOUR_PRIVATE_KEY', provider);

// Contract addresses
const PHII_COIN = '0x6eAc85faD7faED5E44853edFA45246704795BeAc';
const SALARY_EWA = '0xD875b836C85047C4eA4584E8B74e7eefE1ccC1bc';

// ABIs (simplified - get full ABI from Basescan)
const phiiAbi = [
  'function balanceOf(address) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function transfer(address to, uint256 amount) returns (bool)'
];

const salaryAbi = [
  'function getEmployeeInfo(address) view returns (uint256,bool,uint256,uint256,uint256,uint256,uint256,uint256)',
  'function registerEmployee(address employee, uint256 monthlySalary)',
  'function fund(uint256 amount)',
  'function withdraw()',
  'function requestAdvance(uint256 amount)',
  'function releaseSalary(address employee)'
];

// Create contract instances
const phiiCoin = new ethers.Contract(PHII_COIN, phiiAbi, wallet);
const salaryEWA = new ethers.Contract(SALARY_EWA, salaryAbi, wallet);

// READ Examples
async function readExamples() {
  // Check balance
  const balance = await phiiCoin.balanceOf(wallet.address);
  console.log('Balance:', ethers.formatEther(balance), 'PHII');
  
  // Get employee info
  const info = await salaryEWA.getEmployeeInfo(wallet.address);
  console.log('Employee Info:', {
    monthlySalary: ethers.formatEther(info[0]),
    active: info[1],
    periodStart: new Date(Number(info[2]) * 1000),
    totalAccrued: ethers.formatEther(info[3]),
    available: ethers.formatEther(info[7])
  });
}

// WRITE Examples
async function writeExamples() {
  // Register employee (Owner only)
  const tx1 = await salaryEWA.registerEmployee(
    '0xEmployeeAddress',
    ethers.parseEther('1000') // 1000 PHII per month
  );
  await tx1.wait();
  console.log('Employee registered:', tx1.hash);
  
  // Approve and fund (Owner only)
  const tx2 = await phiiCoin.approve(
    SALARY_EWA,
    ethers.parseEther('10000')
  );
  await tx2.wait();
  
  const tx3 = await salaryEWA.fund(ethers.parseEther('10000'));
  await tx3.wait();
  console.log('Funded:', tx3.hash);
  
  // Employee withdraw
  const tx4 = await salaryEWA.withdraw();
  await tx4.wait();
  console.log('Withdrawn:', tx4.hash);
  
  // Request advance
  const tx5 = await salaryEWA.requestAdvance(ethers.parseEther('500'));
  await tx5.wait();
  console.log('Advance requested:', tx5.hash);
}
```

---

## 📱 Method 4: Using Mobile Wallet (MetaMask Mobile)

1. **Install MetaMask Mobile**
2. **Add Base Sepolia Network** (same settings as desktop)
3. **Import PHII Token** (same address)
4. **Open Basescan in mobile browser:**
   - Go to contract address
   - Click "Write Contract"
   - Click "Connect to Web3"
   - Select "MetaMask" and approve
5. **Call functions** same as desktop method

---

## 🔐 Security Notes

1. **Never share your private key**
2. **Always verify contract addresses** before interacting
3. **Start with small amounts** when testing
4. **Double-check function parameters** before submitting
5. **Only owner can call** owner-restricted functions
6. **Employees can only withdraw** their own accrued salary

---

## 📊 Common Use Cases

### For Employer (Contract Owner)

1. **Register New Employee:**
   ```
   Function: registerEmployee
   Params: 
   - employee: 0xEmployeeAddress
   - monthlySalary: 1000000000000000000000 (1000 PHII)
   ```

2. **Fund Payroll:**
   ```
   Step 1: Approve tokens
   Function: approve (on PhiiCoin)
   Params:
   - spender: 0xD875b836C85047C4eA4584E8B74e7eefE1ccC1bc
   - amount: 100000000000000000000000 (100k PHII)
   
   Step 2: Fund
   Function: fund (on SalaryEWA)
   Params:
   - amount: 100000000000000000000000
   ```

3. **Release Monthly Salary:**
   ```
   Function: releaseSalary
   Params:
   - employee: 0xEmployeeAddress
   ```

### For Employee

1. **Check Available Salary:**
   ```
   Function: getEmployeeInfo (Read)
   Params:
   - employee: YourAddress
   Look at: availableToWithdraw (last value)
   ```

2. **Withdraw Accrued Salary:**
   ```
   Function: withdraw
   No params needed
   ```

3. **Request Advance (50% max):**
   ```
   Function: requestAdvance
   Params:
   - amount: 500000000000000000000 (500 PHII)
   Note: Can only request once per pay period
   ```

---

## 🆘 Troubleshooting

**"Transaction reverted"**
- Check if you have the right permissions (owner vs employee)
- Ensure contract has enough balance
- Verify you're not requesting more than available

**"Insufficient funds"**
- Make sure you have ETH for gas fees
- Get testnet ETH from: https://www.alchemy.com/faucets/base-sepolia

**"Not active employee"**
- You must be registered as an employee first
- Check with `getEmployeeInfo` if you're active

**"No available to withdraw"**
- Wait for salary to accrue over time
- Check `availableToWithdraw` value

---

## 📚 Additional Resources

- **Basescan Contract Pages:**
  - [PhiiCoin](https://sepolia.basescan.org/address/0x6eAc85faD7faED5E44853edFA45246704795BeAc)
  - [SalaryEWA](https://sepolia.basescan.org/address/0xD875b836C85047C4eA4584E8B74e7eefE1ccC1bc)

- **Documentation:**
  - [Foundry Book](https://book.getfoundry.sh/)
  - [Ethers.js Docs](https://docs.ethers.org/)
  - [Base Docs](https://docs.base.org/)

- **Get Testnet ETH:**
  - [Alchemy Faucet](https://www.alchemy.com/faucets/base-sepolia)
  - [QuickNode Faucet](https://faucet.quicknode.com/base/sepolia)
