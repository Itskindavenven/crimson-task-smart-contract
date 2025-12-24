#!/bin/bash

# ============================================
# DEPLOYMENT SCRIPT - SALARY EWA SYSTEM
# ============================================
# Script untuk deploy ke EduChain Testnet
# ============================================

set -e  # Exit on error

echo "========================================"
echo "SALARY EWA DEPLOYMENT SCRIPT"
echo "========================================"

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please copy .env.example to .env and fill in your PRIVATE_KEY"
    exit 1
fi

# Load environment variables
source .env

# Check if PRIVATE_KEY is set
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Error: PRIVATE_KEY not set in .env file!"
    exit 1
fi

echo "✅ Environment variables loaded"
echo ""

# Compile contracts
echo "📦 Compiling contracts..."
forge build
echo "✅ Compilation successful"
echo ""

# Run tests
echo "🧪 Running tests..."
forge test
if [ $? -ne 0 ]; then
    echo "❌ Tests failed! Please fix before deploying."
    exit 1
fi
echo "✅ All tests passed"
echo ""

# Deploy
echo "🚀 Deploying to EduChain Testnet..."
echo ""

forge script script/DeployToken.s.sol:DeployToken \
    --rpc-url educhain \
    --broadcast \
    --verify \
    -vvvv

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "✅ DEPLOYMENT SUCCESSFUL!"
    echo "========================================"
    echo ""
    echo "📝 Next steps:"
    echo "1. Copy contract addresses from output above"
    echo "2. Update .env file with deployed addresses"
    echo "3. Verify contracts on block explorer"
    echo "4. Test contract interactions"
    echo ""
    echo "Block Explorer: https://edu-chain-testnet.blockscout.com/"
    echo "========================================"
else
    echo ""
    echo "========================================"
    echo "❌ DEPLOYMENT FAILED"
    echo "========================================"
    echo ""
    echo "Please check the error messages above"
    echo "Common issues:"
    echo "- Insufficient EDU balance for gas"
    echo "- Invalid PRIVATE_KEY in .env"
    echo "- Network connectivity issues"
    echo ""
    exit 1
fi
