// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/PhiiCoin.sol";
import "../src/SalaryEWA.sol";

contract AdminTest is Test {
    PhiiCoin token;
    SalaryEWA payroll;
    address owner = address(0xABCD);
    address nonOwner = address(0x123);
    address alice = address(0x1);
    address bob = address(0x2);

    uint256 constant ONE_MONTH = 30 days;

    function setUp() public {
        vm.warp(1); // reset timestamp so all periodStart = 1
        vm.startPrank(owner);
        token = new PhiiCoin(1_000_000 ether);
        payroll = new SalaryEWA(owner, IERC20(address(token)), ONE_MONTH);
        vm.stopPrank();
    }

    function test_onlyOwnerCanRegister() public {
        // non-owner cannot register
        vm.startPrank(nonOwner);
        vm.expectRevert();
        payroll.registerEmployee(alice, 1000 ether);
        vm.stopPrank();

        // owner can register
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.stopPrank();

        (, , uint256 periodStart, , , , ,) = payroll.getEmployeeInfo(alice);
        assertTrue(periodStart > 0);
    }

    function test_refund_revertsWhenLocked() public {
        vm.startPrank(owner);
        payroll.registerEmployee(bob, 1000 ether);
        token.approve(address(payroll), 1000 ether);
        payroll.fund(1000 ether);

        vm.warp(block.timestamp + 1 hours); // FIX: now accrued > 0 (≈1.38 tokens)

        vm.expectRevert();
        payroll.refund(1000 ether);
        vm.stopPrank();
    }

    function test_refund_succeedsWhenFreeFunds() public {
        vm.startPrank(owner);
        // no employees -> entire fund is free
        token.approve(address(payroll), 500 ether);
        payroll.fund(500 ether);

        uint256 beforeBalance = token.balanceOf(owner);
        payroll.refund(100 ether);
        uint256 afterBalance = token.balanceOf(owner);

        // owner should receive refund
        assertEq(afterBalance, beforeBalance + 100 ether);
        vm.stopPrank();
    }

    function test_emergencyWithdraw_requires_freeFunds() public {
        vm.warp(1); // ensure deterministic timestamps
        vm.startPrank(owner);
        payroll.registerEmployee(bob, 1000 ether);
        token.approve(address(payroll), 500 ether);
        payroll.fund(500 ether);

        // advance time a bit so there's non-zero accrual (locked > 0)
        vm.warp(block.timestamp + 1 hours);

        // compute locked via public getter
        (
        ,
        ,
        ,
        uint256 totalAccrued,
        uint256 withdrawnInPeriod,
        uint256 outstandingAdvance,
        ,
        
        ) = payroll.getEmployeeInfo(bob);

        uint256 remainingAccrued = 0;
        if (totalAccrued > withdrawnInPeriod) {
            remainingAccrued = totalAccrued - withdrawnInPeriod;
        }
        uint256 locked = remainingAccrued + outstandingAdvance;

        // contract balance
        uint256 contractBal = token.balanceOf(address(payroll));

        // free funds = contractBal - locked
        // attempt to emergencyWithdraw (free funds + 1) should revert
        // compute amount that exceeds free funds by 1 wei
        uint256 attempt = 0;
        if (contractBal > locked) {
            attempt = (contractBal - locked) + 1;
        } else {
            // if locked >= contractBal, any positive withdrawal should revert
            attempt = 1;
        }

        vm.expectRevert();
        payroll.emergencyWithdraw(owner, attempt);

        // now fund extra to create explicit free funds and test successful emergencyWithdraw
        token.approve(address(payroll), 1000 ether);
        payroll.fund(1000 ether);

        // now there should be some free funds; withdraw a small amount
        payroll.emergencyWithdraw(owner, 50 ether);
        vm.stopPrank();
    }

    function test_pause_unpause() public {
        vm.startPrank(owner);
        payroll.pause();
        // Owner can still unpause
        payroll.unpause();
        vm.stopPrank();

        // Non-owner cannot pause
        vm.startPrank(nonOwner);
        vm.expectRevert();
        payroll.pause();
        vm.stopPrank();
    }
}
