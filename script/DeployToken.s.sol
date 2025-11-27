// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/PhiiCoin.sol";
import "../src/SalaryEWA.sol";

contract DeployToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying from:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);

        PhiiCoin token = new PhiiCoin(2_000_000 ether);
        console.log("PhiiCoin deployed:", address(token));

        uint256 payPeriodSeconds = 30 days;
        SalaryEWA payroll = new SalaryEWA(deployer, token, payPeriodSeconds);
        console.log("SalaryEWA deployed:", address(payroll));

        vm.stopBroadcast();
    }
}