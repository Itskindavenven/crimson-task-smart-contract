// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/PhiiCoin.sol";
import "../src/SalaryEWA.sol";

/// @title PayrollSystem Test Suite
/// @notice Comprehensive tests for core payroll functionality
contract PayrollSystemTest is Test {
    PhiiCoin token;
    SalaryEWA payroll;
    address owner = address(0xABCD);
    address nonOwner = address(0x999);
    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);

    uint256 constant ONE_MONTH = 30 days;
    uint256 constant INITIAL_SUPPLY = 10_000_000 ether;

    event EmployeeRegistered(
        address indexed employee,
        uint256 monthlySalary,
        uint256 periodStart
    );
    event EmployeeUpdated(
        address indexed employee,
        uint256 monthlySalary,
        bool active
    );
    event Funded(address indexed by, uint256 amount);
    event Withdrawn(address indexed employee, uint256 amount);
    event Refunded(address indexed to, uint256 amount);
    event PausedEvent(address account);
    event UnpausedEvent(address account);

    function setUp() public {
        vm.warp(1000); // Set deterministic timestamp
        vm.startPrank(owner);
        token = new PhiiCoin(INITIAL_SUPPLY);
        payroll = new SalaryEWA(owner, IERC20(address(token)), ONE_MONTH);
        vm.stopPrank();
    }

    // ========== EMPLOYEE REGISTRATION TESTS ==========

    function test_registerEmployee_success() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true);
        emit EmployeeRegistered(alice, 1000 ether, block.timestamp);

        payroll.registerEmployee(alice, 1000 ether);

        (uint256 salary, bool active, uint256 periodStart, , , , , ) = payroll
            .getEmployeeInfo(alice);

        assertEq(salary, 1000 ether, "Salary should be set correctly");
        assertTrue(active, "Employee should be active");
        assertEq(
            periodStart,
            block.timestamp,
            "Period start should be current timestamp"
        );
        assertEq(payroll.employeesCount(), 1, "Employee count should be 1");

        vm.stopPrank();
    }

    function test_registerEmployee_onlyOwner() public {
        vm.startPrank(nonOwner);

        vm.expectRevert();
        payroll.registerEmployee(alice, 1000 ether);

        vm.stopPrank();
    }

    function test_registerEmployee_zeroAddress() public {
        vm.startPrank(owner);

        vm.expectRevert("zero addr");
        payroll.registerEmployee(address(0), 1000 ether);

        vm.stopPrank();
    }

    function test_registerEmployee_zeroSalary() public {
        vm.startPrank(owner);

        vm.expectRevert("salary>0");
        payroll.registerEmployee(alice, 0);

        vm.stopPrank();
    }

    function test_registerEmployee_updateExisting() public {
        vm.startPrank(owner);

        // Register first time
        payroll.registerEmployee(alice, 1000 ether);
        uint256 firstPeriodStart = block.timestamp;

        // Wait some time
        vm.warp(block.timestamp + 1 days);

        // Register again with different salary
        payroll.registerEmployee(alice, 2000 ether);

        (uint256 salary, bool active, uint256 periodStart, , , , , ) = payroll
            .getEmployeeInfo(alice);

        assertEq(salary, 2000 ether, "Salary should be updated");
        assertTrue(active, "Employee should still be active");
        assertEq(
            periodStart,
            firstPeriodStart,
            "Period start should not change on update"
        );
        assertEq(
            payroll.employeesCount(),
            1,
            "Employee count should still be 1"
        );

        vm.stopPrank();
    }

    // ========== FUNDING TESTS ==========

    function test_fund_success() public {
        vm.startPrank(owner);

        uint256 fundAmount = 10000 ether;
        token.approve(address(payroll), fundAmount);

        uint256 balanceBefore = token.balanceOf(owner);

        vm.expectEmit(true, false, false, true);
        emit Funded(owner, fundAmount);

        payroll.fund(fundAmount);

        uint256 balanceAfter = token.balanceOf(owner);
        uint256 contractBalance = token.balanceOf(address(payroll));

        assertEq(
            balanceBefore - balanceAfter,
            fundAmount,
            "Owner balance should decrease"
        );
        assertEq(contractBalance, fundAmount, "Contract should receive tokens");

        vm.stopPrank();
    }

    function test_fund_onlyOwner() public {
        vm.startPrank(nonOwner);

        vm.expectRevert();
        payroll.fund(1000 ether);

        vm.stopPrank();
    }

    function test_fund_zeroAmount() public {
        vm.startPrank(owner);

        vm.expectRevert("amount>0");
        payroll.fund(0);

        vm.stopPrank();
    }

    function test_fund_withoutApproval() public {
        vm.startPrank(owner);

        // Don't approve tokens
        vm.expectRevert();
        payroll.fund(1000 ether);

        vm.stopPrank();
    }

    // ========== LINEAR ACCRUAL TESTS ==========

    function test_accrual_zeroAtStart() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.stopPrank();

        (, , , uint256 totalAccrued, , , , uint256 available) = payroll
            .getEmployeeInfo(alice);

        assertEq(totalAccrued, 0, "Accrual should be zero at start");
        assertEq(available, 0, "Available should be zero at start");
    }

    function test_accrual_linear() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 3000 ether); // 3000 per month
        vm.stopPrank();

        // After 10 days (1/3 of month)
        vm.warp(block.timestamp + 10 days);
        (, , , uint256 accrued10, , , , ) = payroll.getEmployeeInfo(alice);

        // Should be approximately 1000 ether (1/3 of 3000)
        assertApproxEqAbs(
            accrued10,
            1000 ether,
            1 ether,
            "Accrual after 10 days should be ~1000"
        );

        // After 20 days (2/3 of month)
        vm.warp(block.timestamp + 10 days);
        (, , , uint256 accrued20, , , , ) = payroll.getEmployeeInfo(alice);

        // Should be approximately 2000 ether (2/3 of 3000)
        assertApproxEqAbs(
            accrued20,
            2000 ether,
            1 ether,
            "Accrual after 20 days should be ~2000"
        );

        // After 30 days (full month)
        vm.warp(block.timestamp + 10 days);
        (, , , uint256 accrued30, , , , ) = payroll.getEmployeeInfo(alice);

        // Should be approximately 3000 ether (full salary)
        assertApproxEqAbs(
            accrued30,
            3000 ether,
            1 ether,
            "Accrual after 30 days should be ~3000"
        );
    }

    function test_accrual_multipleEmployees() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        payroll.registerEmployee(bob, 2000 ether);
        payroll.registerEmployee(carol, 1500 ether);
        vm.stopPrank();

        // After 15 days (half month)
        vm.warp(block.timestamp + 15 days);

        (, , , uint256 aliceAccrued, , , , ) = payroll.getEmployeeInfo(alice);
        (, , , uint256 bobAccrued, , , , ) = payroll.getEmployeeInfo(bob);
        (, , , uint256 carolAccrued, , , , ) = payroll.getEmployeeInfo(carol);

        assertApproxEqAbs(
            aliceAccrued,
            500 ether,
            1 ether,
            "Alice accrual should be ~500"
        );
        assertApproxEqAbs(
            bobAccrued,
            1000 ether,
            1 ether,
            "Bob accrual should be ~1000"
        );
        assertApproxEqAbs(
            carolAccrued,
            750 ether,
            1 ether,
            "Carol accrual should be ~750"
        );
    }

    // ========== WITHDRAWAL TESTS ==========

    function test_withdraw_success() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 2000 ether);
        payroll.fund(2000 ether);
        vm.stopPrank();

        // Wait for some accrual
        vm.warp(block.timestamp + 15 days); // Half month = ~500 ether accrued

        vm.startPrank(alice);

        uint256 balanceBefore = token.balanceOf(alice);

        vm.expectEmit(true, false, false, false);
        emit Withdrawn(alice, 0); // Amount will vary

        payroll.withdraw();

        uint256 balanceAfter = token.balanceOf(alice);
        uint256 withdrawn = balanceAfter - balanceBefore;

        assertApproxEqAbs(
            withdrawn,
            500 ether,
            1 ether,
            "Withdrawn amount should be ~500"
        );

        vm.stopPrank();
    }

    function test_withdraw_onlyActiveEmployee() public {
        // Alice not registered
        vm.startPrank(alice);

        vm.expectRevert("not active employee");
        payroll.withdraw();

        vm.stopPrank();
    }

    function test_withdraw_noAvailable() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.stopPrank();

        // No time passed, no accrual
        vm.startPrank(alice);

        vm.expectRevert("no available to withdraw");
        payroll.withdraw();

        vm.stopPrank();
    }

    function test_withdraw_updatesWithdrawnInPeriod() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 2000 ether);
        payroll.fund(2000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        vm.prank(alice);
        payroll.withdraw();

        (
            ,
            ,
            ,
            uint256 totalAccrued,
            uint256 withdrawnInPeriod,
            ,
            ,
            uint256 available
        ) = payroll.getEmployeeInfo(alice);

        assertApproxEqAbs(
            withdrawnInPeriod,
            500 ether,
            1 ether,
            "Withdrawn in period should be ~500"
        );
        assertEq(available, 0, "Available should be 0 after full withdrawal");
    }

    // ========== REFUND TESTS ==========

    function test_refund_success() public {
        vm.startPrank(owner);

        // Fund without employees (all funds are free)
        token.approve(address(payroll), 1000 ether);
        payroll.fund(1000 ether);

        uint256 balanceBefore = token.balanceOf(owner);

        vm.expectEmit(true, false, false, true);
        emit Refunded(owner, 500 ether);

        payroll.refund(500 ether);

        uint256 balanceAfter = token.balanceOf(owner);

        assertEq(
            balanceAfter - balanceBefore,
            500 ether,
            "Owner should receive refund"
        );

        vm.stopPrank();
    }

    function test_refund_cannotRefundLockedFunds() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 1000 ether);
        payroll.fund(1000 ether);
        vm.stopPrank();

        // Wait for accrual
        vm.warp(block.timestamp + 15 days); // ~500 ether locked

        vm.startPrank(owner);

        // Try to refund more than free funds
        vm.expectRevert("insufficient free funds");
        payroll.refund(600 ether);

        vm.stopPrank();
    }

    function test_refund_onlyOwner() public {
        vm.startPrank(nonOwner);

        vm.expectRevert();
        payroll.refund(100 ether);

        vm.stopPrank();
    }

    function test_refund_zeroAmount() public {
        vm.startPrank(owner);

        vm.expectRevert("amount>0");
        payroll.refund(0);

        vm.stopPrank();
    }

    // ========== PAUSE/UNPAUSE TESTS ==========

    function test_pause_unpause() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, false);
        emit PausedEvent(owner);

        payroll.pause();

        // Try to register while paused
        vm.expectRevert();
        payroll.registerEmployee(alice, 1000 ether);

        vm.expectEmit(true, false, false, false);
        emit UnpausedEvent(owner);

        payroll.unpause();

        // Should work after unpause
        payroll.registerEmployee(alice, 1000 ether);

        vm.stopPrank();
    }

    function test_pause_onlyOwner() public {
        vm.startPrank(nonOwner);

        vm.expectRevert();
        payroll.pause();

        vm.stopPrank();
    }

    function test_pause_blocksOperations() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 2000 ether);
        payroll.fund(2000 ether);
        payroll.pause();
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        // Employee operations should be blocked
        vm.startPrank(alice);
        vm.expectRevert();
        payroll.withdraw();
        vm.stopPrank();

        // Owner operations should be blocked (except pause/unpause)
        vm.startPrank(owner);
        vm.expectRevert();
        payroll.fund(100 ether);

        vm.expectRevert();
        payroll.refund(100 ether);
        vm.stopPrank();
    }

    // ========== EMPLOYEE DEACTIVATION TESTS ==========

    function test_deactivate_employee() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);

        vm.expectEmit(true, false, false, true);
        emit EmployeeUpdated(alice, 1000 ether, false);

        payroll.updateEmployee(alice, 1000 ether, false);

        (, bool active, , , , , , ) = payroll.getEmployeeInfo(alice);
        assertFalse(active, "Employee should be deactivated");

        vm.stopPrank();
    }

    function test_deactivated_cannotWithdraw() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 2000 ether);
        payroll.fund(2000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        // Deactivate alice
        vm.prank(owner);
        payroll.updateEmployee(alice, 1000 ether, false);

        // Alice cannot withdraw
        vm.startPrank(alice);
        vm.expectRevert("not active employee");
        payroll.withdraw();
        vm.stopPrank();
    }

    function test_updateEmployee_onlyOwner() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.stopPrank();

        vm.startPrank(nonOwner);
        vm.expectRevert();
        payroll.updateEmployee(alice, 2000 ether, true);
        vm.stopPrank();
    }

    function test_updateEmployee_notRegistered() public {
        vm.startPrank(owner);

        vm.expectRevert("not registered");
        payroll.updateEmployee(alice, 1000 ether, true);

        vm.stopPrank();
    }
}
