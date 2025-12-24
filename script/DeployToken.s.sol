// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/PhiiCoin.sol";
import "../src/SalaryEWA.sol";

contract DeployToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("========================================");
        console.log("DEPLOYING SALARY EWA SYSTEM");
        console.log("========================================");
        console.log("Deployer Address:", deployer);
        console.log("Network: EduChain Testnet");
        console.log("========================================");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy PhiiCoin with 2M initial supply
        console.log("\n1. Deploying PhiiCoin...");
        PhiiCoin token = new PhiiCoin(2_000_000 ether);
        console.log("   PhiiCoin deployed at:", address(token));
        console.log("   Initial Supply:", 2_000_000, "PHII");

        // Deploy SalaryEWA with 30-day pay period
        console.log("\n2. Deploying SalaryEWA...");
        uint256 payPeriodSeconds = 30 days;
        SalaryEWA payroll = new SalaryEWA(deployer, token, payPeriodSeconds);
        console.log("   SalaryEWA deployed at:", address(payroll));
        console.log("   Pay Period:", payPeriodSeconds / 1 days, "days");
        console.log("   Owner:", deployer);

        // Optional: Fund the payroll contract with initial tokens
        console.log("\n3. Initial Setup...");
        uint256 initialFunding = 100_000 ether;
        token.approve(address(payroll), initialFunding);
        payroll.fund(initialFunding);
        console.log(
            "   Funded payroll with:",
            initialFunding / 1 ether,
            "PHII"
        );

        vm.stopBroadcast();

        console.log("\n========================================");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("========================================");
        console.log("PhiiCoin Address:", address(token));
        console.log("SalaryEWA Address:", address(payroll));
        console.log("========================================");
        console.log("\nSave these addresses to your .env file:");
        console.log("PHII_COIN_ADDRESS=", address(token));
        console.log("SALARY_EWA_ADDRESS=", address(payroll));
        console.log("========================================");
    }
}
