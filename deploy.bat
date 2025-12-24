@echo off
REM ============================================
REM DEPLOYMENT SCRIPT - SALARY EWA SYSTEM
REM ============================================
REM Script untuk deploy ke EduChain Testnet (Windows)
REM ============================================

echo ========================================
echo SALARY EWA DEPLOYMENT SCRIPT
echo ========================================
echo.

REM Check if .env exists
if not exist .env (
    echo Error: .env file not found!
    echo Please copy .env.example to .env and fill in your PRIVATE_KEY
    exit /b 1
)

echo Environment file found
echo.

REM Compile contracts
echo Compiling contracts...
forge build
if errorlevel 1 (
    echo Compilation failed!
    exit /b 1
)
echo Compilation successful
echo.

REM Run tests
echo Running tests...
forge test
if errorlevel 1 (
    echo Tests failed! Please fix before deploying.
    exit /b 1
)
echo All tests passed
echo.

REM Deploy
echo Deploying to EduChain Testnet...
echo.

forge script script/DeployToken.s.sol:DeployToken --rpc-url educhain --broadcast --verify -vvvv

if errorlevel 1 (
    echo.
    echo ========================================
    echo DEPLOYMENT FAILED
    echo ========================================
    echo.
    echo Please check the error messages above
    echo Common issues:
    echo - Insufficient EDU balance for gas
    echo - Invalid PRIVATE_KEY in .env
    echo - Network connectivity issues
    echo.
    exit /b 1
)

echo.
echo ========================================
echo DEPLOYMENT SUCCESSFUL!
echo ========================================
echo.
echo Next steps:
echo 1. Copy contract addresses from output above
echo 2. Update .env file with deployed addresses
echo 3. Verify contracts on block explorer
echo 4. Test contract interactions
echo.
echo Block Explorer: https://edu-chain-testnet.blockscout.com/
echo ========================================
