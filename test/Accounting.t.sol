// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/PhiiCoin.sol";
import "../src/SalaryEWA.sol";

/// @title Accounting Test Suite
/// @notice Tests for balance tracking and accounting integrity
contract AccountingTest is Test {
    PhiiCoin token;
    SalaryEWA payroll;
    address owner = address(0xABCD);
    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);

    uint256 constant ONE_MONTH = 30 days;
    uint256 constant INITIAL_SUPPLY = 10_000_000 ether;

    function setUp() public {
        vm.warp(1000);
        vm.startPrank(owner);
        token = new PhiiCoin(INITIAL_SUPPLY);
        payroll = new SalaryEWA(owner, IERC20(address(token)), ONE_MONTH);
        vm.stopPrank();
    }

    // ========== PER-EMPLOYEE BALANCE TRACKING ==========

    function test_perEmployee_balances() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);
        vm.stopPrank();

        // Check initial state
        (
            uint256 salary,
            bool active,
            uint256 periodStart,
            uint256 totalAccrued,
            uint256 withdrawnInPeriod,
            uint256 outstandingAdvance,
            ,
            uint256 available
        ) = payroll.getEmployeeInfo(alice);

        assertEq(salary, 1000 ether, "Salary should be set");
        assertTrue(active, "Should be active");
        assertGt(periodStart, 0, "Period start should be set");
        assertEq(totalAccrued, 0, "No accrual yet");
        assertEq(withdrawnInPeriod, 0, "No withdrawals yet");
        assertEq(outstandingAdvance, 0, "No advance yet");
        assertEq(available, 0, "No available yet");

        // Accrue some salary
        vm.warp(block.timestamp + 15 days);

        (
            ,
            ,
            ,
            totalAccrued,
            withdrawnInPeriod,
            outstandingAdvance,
            ,
            available
        ) = payroll.getEmployeeInfo(alice);

        assertApproxEqAbs(
            totalAccrued,
            500 ether,
            1 ether,
            "Should accrue ~500"
        );
        assertEq(withdrawnInPeriod, 0, "Still no withdrawals");
        assertEq(outstandingAdvance, 0, "Still no advance");
        assertApproxEqAbs(
            available,
            500 ether,
            1 ether,
            "Available should equal accrued"
        );

        // Take advance
        uint256 advance = available / 2;
        vm.prank(alice);
        payroll.requestAdvance(advance);

        (
            ,
            ,
            ,
            totalAccrued,
            withdrawnInPeriod,
            outstandingAdvance,
            ,
            available
        ) = payroll.getEmployeeInfo(alice);

        assertApproxEqAbs(
            outstandingAdvance,
            250 ether,
            1 ether,
            "Outstanding should be ~250"
        );
        assertApproxEqAbs(
            available,
            250 ether,
            1 ether,
            "Available reduced by advance"
        );

        // Withdraw remaining
        vm.prank(alice);
        payroll.withdraw();

        (
            ,
            ,
            ,
            totalAccrued,
            withdrawnInPeriod,
            outstandingAdvance,
            ,
            available
        ) = payroll.getEmployeeInfo(alice);

        assertApproxEqAbs(
            withdrawnInPeriod,
            250 ether,
            1 ether,
            "Withdrawn should be ~250"
        );
        assertEq(available, 0, "No more available");
    }

    function test_multipleEmployees_independentBalances() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        payroll.registerEmployee(bob, 2000 ether);
        payroll.registerEmployee(carol, 1500 ether);
        token.approve(address(payroll), 20000 ether);
        payroll.fund(20000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        // Alice takes advance
        (, , , , , , , uint256 aliceAvail) = payroll.getEmployeeInfo(alice);
        vm.prank(alice);
        payroll.requestAdvance(aliceAvail / 2);

        // Bob withdraws
        vm.prank(bob);
        payroll.withdraw();

        // Carol does nothing

        // Check balances are independent
        (, , , , uint256 aliceWithdrawn, uint256 aliceAdvance, , ) = payroll
            .getEmployeeInfo(alice);
        (, , , , uint256 bobWithdrawn, uint256 bobAdvance, , ) = payroll
            .getEmployeeInfo(bob);
        (, , , , uint256 carolWithdrawn, uint256 carolAdvance, , ) = payroll
            .getEmployeeInfo(carol);

        assertEq(aliceWithdrawn, 0, "Alice didn't withdraw");
        assertGt(aliceAdvance, 0, "Alice has advance");

        assertGt(bobWithdrawn, 0, "Bob withdrew");
        assertEq(bobAdvance, 0, "Bob has no advance");

        assertEq(carolWithdrawn, 0, "Carol didn't withdraw");
        assertEq(carolAdvance, 0, "Carol has no advance");
    }

    // ========== GLOBAL ACCOUNTING TOTALS ==========

    function test_global_totalFunded() public {
        vm.startPrank(owner);

        token.approve(address(payroll), 10000 ether);
        payroll.fund(5000 ether);

        assertEq(
            payroll.totalFunded(),
            5000 ether,
            "Total funded should be 5000"
        );

        payroll.fund(3000 ether);

        assertEq(
            payroll.totalFunded(),
            8000 ether,
            "Total funded should be 8000"
        );

        vm.stopPrank();
    }

    function test_global_totalWithdrawn() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        payroll.registerEmployee(bob, 1000 ether);
        token.approve(address(payroll), 10000 ether);
        payroll.fund(10000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        // Alice withdraws
        vm.prank(alice);
        payroll.withdraw();

        uint256 aliceAmount = token.balanceOf(alice);
        assertApproxEqAbs(
            payroll.totalWithdrawn(),
            aliceAmount,
            1,
            "Total withdrawn should match Alice's withdrawal"
        );

        // Bob withdraws
        vm.prank(bob);
        payroll.withdraw();

        uint256 bobAmount = token.balanceOf(bob);
        assertApproxEqAbs(
            payroll.totalWithdrawn(),
            aliceAmount + bobAmount,
            1,
            "Total withdrawn should be sum"
        );
    }

    function test_global_totalWithdrawn_includesAdvances() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 10000 ether);
        payroll.fund(10000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        (, , , , , , , uint256 available) = payroll.getEmployeeInfo(alice);
        uint256 advance = available / 2;

        vm.prank(alice);
        payroll.requestAdvance(advance);

        // Advances count as withdrawn
        assertApproxEqAbs(
            payroll.totalWithdrawn(),
            advance,
            1,
            "Advance should count in total withdrawn"
        );
    }

    function test_global_totalRefunded() public {
        vm.startPrank(owner);

        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);

        payroll.refund(1000 ether);
        assertEq(
            payroll.totalRefunded(),
            1000 ether,
            "Total refunded should be 1000"
        );

        payroll.refund(500 ether);
        assertEq(
            payroll.totalRefunded(),
            1500 ether,
            "Total refunded should be 1500"
        );

        vm.stopPrank();
    }

    function test_global_emergencyWithdraw_countsAsRefund() public {
        vm.startPrank(owner);

        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);

        payroll.emergencyWithdraw(owner, 1000 ether);
        assertEq(
            payroll.totalRefunded(),
            1000 ether,
            "Emergency withdraw should count as refund"
        );

        vm.stopPrank();
    }

    // ========== ACCOUNTING INTEGRITY ==========

    function test_accounting_balanceEquality() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        payroll.registerEmployee(bob, 1000 ether);

        token.approve(address(payroll), 10000 ether);
        payroll.fund(10000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        // Alice withdraws
        vm.prank(alice);
        payroll.withdraw();

        // Bob takes advance
        (, , , , , , , uint256 bobAvail) = payroll.getEmployeeInfo(bob);
        vm.prank(bob);
        payroll.requestAdvance(bobAvail / 2);

        // Owner refunds some
        vm.prank(owner);
        payroll.refund(1000 ether);

        // Check: totalFunded = contractBalance + totalWithdrawn + totalRefunded
        uint256 contractBalance = token.balanceOf(address(payroll));
        uint256 totalFunded = payroll.totalFunded();
        uint256 totalWithdrawn = payroll.totalWithdrawn();
        uint256 totalRefunded = payroll.totalRefunded();

        assertApproxEqAbs(
            totalFunded,
            contractBalance + totalWithdrawn + totalRefunded,
            2,
            "Accounting equation should hold"
        );
    }

    function test_accounting_periodReset() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 10000 ether);
        payroll.fund(10000 ether);
        vm.stopPrank();

        // First period
        vm.warp(block.timestamp + 15 days);

        vm.prank(alice);
        payroll.withdraw();

        (, , , , uint256 withdrawn1, uint256 advance1, , ) = payroll
            .getEmployeeInfo(alice);
        assertGt(withdrawn1, 0, "Should have withdrawn");

        // Release salary (resets period)
        vm.warp(block.timestamp + 16 days);
        vm.prank(owner);
        payroll.releaseSalary(alice);

        // Check reset
        (
            ,
            ,
            uint256 newPeriodStart,
            ,
            uint256 withdrawn2,
            uint256 advance2,
            ,

        ) = payroll.getEmployeeInfo(alice);

        assertGt(newPeriodStart, 1000, "Period should restart");
        assertEq(withdrawn2, 0, "Withdrawn should reset");
        assertEq(advance2, 0, "Advance should reset");
    }

    // ========== SAFEERC20 VALIDATION ==========

    function test_safeERC20_fund() public {
        vm.startPrank(owner);

        // Without approval should fail
        vm.expectRevert();
        payroll.fund(1000 ether);

        // With approval should succeed
        token.approve(address(payroll), 1000 ether);
        payroll.fund(1000 ether);

        vm.stopPrank();
    }

    function test_safeERC20_withdraw() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        payroll.withdraw();

        uint256 balanceAfter = token.balanceOf(alice);

        // SafeERC20 ensures transfer succeeded
        assertGt(balanceAfter, balanceBefore, "Balance should increase");
    }

    function test_safeERC20_refund() public {
        vm.startPrank(owner);

        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);

        uint256 balanceBefore = token.balanceOf(owner);

        payroll.refund(1000 ether);

        uint256 balanceAfter = token.balanceOf(owner);

        assertEq(
            balanceAfter - balanceBefore,
            1000 ether,
            "Refund should transfer correctly"
        );

        vm.stopPrank();
    }

    // ========== EMPLOYEE COUNT ==========

    function test_employeesCount() public {
        assertEq(payroll.employeesCount(), 0, "Should start with 0 employees");

        vm.startPrank(owner);

        payroll.registerEmployee(alice, 1000 ether);
        assertEq(payroll.employeesCount(), 1, "Should have 1 employee");

        payroll.registerEmployee(bob, 1000 ether);
        assertEq(payroll.employeesCount(), 2, "Should have 2 employees");

        payroll.registerEmployee(carol, 1000 ether);
        assertEq(payroll.employeesCount(), 3, "Should have 3 employees");

        // Re-registering doesn't increase count
        payroll.registerEmployee(alice, 2000 ether);
        assertEq(payroll.employeesCount(), 3, "Should still have 3 employees");

        vm.stopPrank();
    }

    function test_lockedFunds_calculation() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        payroll.registerEmployee(bob, 2000 ether);
        token.approve(address(payroll), 10000 ether);
        payroll.fund(10000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        // Alice takes advance
        (, , , , , , , uint256 aliceAvail) = payroll.getEmployeeInfo(alice);
        vm.prank(alice);
        payroll.requestAdvance(aliceAvail / 2);

        // Try to refund - should account for locked funds
        uint256 contractBalance = token.balanceOf(address(payroll));

        vm.startPrank(owner);

        // Cannot refund all (some is locked)
        vm.expectRevert("insufficient free funds");
        payroll.refund(contractBalance);

        vm.stopPrank();
    }
}
