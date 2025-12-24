// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/PhiiCoin.sol";
import "../src/SalaryEWA.sol";

/// @title EWA (Earned Wage Access) Test Suite
/// @notice Comprehensive tests for advance request and settlement features
contract EWATest is Test {
    PhiiCoin token;
    SalaryEWA payroll;
    address owner = address(0xABCD);
    address alice = address(0x1);
    address bob = address(0x2);

    uint256 constant ONE_MONTH = 30 days;
    uint256 constant INITIAL_SUPPLY = 10_000_000 ether;

    event AdvanceRequested(address indexed employee, uint256 amount);
    event AdvanceRepaid(
        address indexed employee,
        uint256 amountRepaid,
        uint256 remainingAdvance
    );
    event Withdrawn(address indexed employee, uint256 amount);

    function setUp() public {
        vm.warp(1000);
        vm.startPrank(owner);
        token = new PhiiCoin(INITIAL_SUPPLY);
        payroll = new SalaryEWA(owner, IERC20(address(token)), ONE_MONTH);
        vm.stopPrank();
    }

    // ========== ADVANCE REQUEST TESTS ==========

    function test_requestAdvance_success() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);
        vm.stopPrank();

        // Wait for some accrual
        vm.warp(block.timestamp + 10 days); // ~333 ether accrued

        (, , , uint256 totalAccrued, , , , uint256 available) = payroll
            .getEmployeeInfo(alice);

        uint256 advanceAmount = available / 2; // 50% of available

        vm.startPrank(alice);

        uint256 balanceBefore = token.balanceOf(alice);

        vm.expectEmit(true, false, false, true);
        emit AdvanceRequested(alice, advanceAmount);

        payroll.requestAdvance(advanceAmount);

        uint256 balanceAfter = token.balanceOf(alice);

        assertEq(
            balanceAfter - balanceBefore,
            advanceAmount,
            "Alice should receive advance"
        );

        (, , , , , uint256 outstanding, , ) = payroll.getEmployeeInfo(alice);
        assertEq(
            outstanding,
            advanceAmount,
            "Outstanding advance should be tracked"
        );

        vm.stopPrank();
    }

    function test_requestAdvance_50percentLimit() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days); // ~500 ether accrued

        (, , , , , , , uint256 available) = payroll.getEmployeeInfo(alice);

        uint256 maxAdvance = available / 2; // 50%
        uint256 tooMuch = maxAdvance + 1 ether;

        vm.startPrank(alice);

        // Should fail - exceeds 50%
        vm.expectRevert("exceeds 50% of current available");
        payroll.requestAdvance(tooMuch);

        // Should succeed - exactly 50%
        payroll.requestAdvance(maxAdvance);

        vm.stopPrank();
    }

    function test_requestAdvance_preventMultipleInSamePeriod() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        (, , , , , , , uint256 available) = payroll.getEmployeeInfo(alice);
        uint256 firstAdvance = available / 4; // 25% (leaving room for second)

        vm.startPrank(alice);

        // First advance succeeds
        payroll.requestAdvance(firstAdvance);

        // Second advance in same period should fail
        vm.expectRevert("advance already this period");
        payroll.requestAdvance(1 ether);

        vm.stopPrank();
    }

    function test_requestAdvance_allowedInNewPeriod() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 10000 ether);
        payroll.fund(10000 ether);
        vm.stopPrank();

        // First period
        vm.warp(block.timestamp + 15 days);

        (, , , , , , , uint256 available1) = payroll.getEmployeeInfo(alice);
        uint256 advance1 = available1 / 2;

        vm.prank(alice);
        payroll.requestAdvance(advance1);

        // Release salary to start new period
        vm.warp(block.timestamp + 16 days); // Past end of period
        vm.prank(owner);
        payroll.releaseSalary(alice);

        // New period - advance should be allowed again
        vm.warp(block.timestamp + 10 days);

        (, , , , , , , uint256 available2) = payroll.getEmployeeInfo(alice);
        uint256 advance2 = available2 / 2;

        vm.prank(alice);
        payroll.requestAdvance(advance2); // Should succeed
    }

    function test_requestAdvance_zeroAmount() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        vm.startPrank(alice);
        vm.expectRevert("amount>0");
        payroll.requestAdvance(0);
        vm.stopPrank();
    }

    function test_requestAdvance_noAccrued() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);
        vm.stopPrank();

        // No time passed
        vm.startPrank(alice);
        vm.expectRevert("no accrued to advance from");
        payroll.requestAdvance(100 ether);
        vm.stopPrank();
    }

    function test_requestAdvance_onlyActiveEmployee() public {
        vm.startPrank(alice);
        vm.expectRevert("not active employee");
        payroll.requestAdvance(100 ether);
        vm.stopPrank();
    }

    function test_requestAdvance_insufficientContractFunds() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        // Fund only 50 ether
        token.approve(address(payroll), 50 ether);
        payroll.fund(50 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days); // ~500 ether accrued

        (, , , , , , , uint256 available) = payroll.getEmployeeInfo(alice);
        uint256 advance = available / 2; // Would be ~250 ether

        vm.startPrank(alice);
        vm.expectRevert("insufficient contract funds");
        payroll.requestAdvance(advance);
        vm.stopPrank();
    }

    function test_requestAdvance_reducesAvailable() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        (, , , , , , , uint256 availableBefore) = payroll.getEmployeeInfo(
            alice
        );
        uint256 advance = availableBefore / 2;

        vm.prank(alice);
        payroll.requestAdvance(advance);

        (, , , , , uint256 outstanding, , uint256 availableAfter) = payroll
            .getEmployeeInfo(alice);

        assertEq(outstanding, advance, "Outstanding should equal advance");
        assertApproxEqAbs(
            availableAfter,
            availableBefore - advance,
            1,
            "Available should decrease by advance amount"
        );
    }

    // ========== PAYDAY SETTLEMENT TESTS ==========

    function test_settlement_deductsAdvance() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);
        vm.stopPrank();

        // Take advance
        vm.warp(block.timestamp + 10 days);
        (, , , , , , , uint256 available) = payroll.getEmployeeInfo(alice);
        uint256 advance = available / 2;

        vm.prank(alice);
        payroll.requestAdvance(advance);

        uint256 balanceAfterAdvance = token.balanceOf(alice);

        // Release salary at end of period
        vm.warp(block.timestamp + 20 days); // Total 30 days (exactly one period)

        vm.prank(owner);

        vm.expectEmit(true, false, false, false);
        emit AdvanceRepaid(alice, 0, 0); // Advance should be repaid

        payroll.releaseSalary(alice);

        uint256 balanceAfterRelease = token.balanceOf(alice);
        uint256 totalReceived = balanceAfterRelease; // Total from advance + release

        // Total should be approximately the monthly salary (allow for rounding)
        assertApproxEqAbs(
            totalReceived,
            1000 ether,
            50 ether,
            "Total received should be ~monthly salary"
        );

        // Outstanding should be zero
        (, , , , , uint256 outstanding, , ) = payroll.getEmployeeInfo(alice);
        assertEq(outstanding, 0, "Outstanding advance should be cleared");
    }

    function test_settlement_paysRemaining() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);
        vm.stopPrank();

        // Take advance
        vm.warp(block.timestamp + 15 days); // ~500 accrued
        (, , , , , , , uint256 available) = payroll.getEmployeeInfo(alice);
        uint256 advance = available / 2; // ~250 ether

        vm.prank(alice);
        payroll.requestAdvance(advance);

        uint256 balanceAfterAdvance = token.balanceOf(alice);

        // Release salary at exactly one period
        vm.warp(block.timestamp + 15 days); // Total 30 days

        vm.prank(owner);
        payroll.releaseSalary(alice);

        uint256 balanceAfterRelease = token.balanceOf(alice);
        uint256 releaseAmount = balanceAfterRelease - balanceAfterAdvance;
        uint256 totalReceived = balanceAfterRelease;

        // Total should be approximately monthly salary
        // Release should be: totalAccrued - advance ~= 1000 - 250 = 750
        assertApproxEqAbs(
            releaseAmount,
            750 ether,
            50 ether,
            "Release should be remaining after advance"
        );
        assertApproxEqAbs(
            totalReceived,
            1000 ether,
            50 ether,
            "Total should be ~monthly salary"
        );
    }

    function test_settlement_partialRepayment() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 5000 ether);
        payroll.fund(5000 ether);
        vm.stopPrank();

        // Take advance early
        vm.warp(block.timestamp + 5 days); // ~166 ether accrued
        (, , , , , , , uint256 available) = payroll.getEmployeeInfo(alice);
        uint256 advance = available / 2; // ~83 ether

        vm.prank(alice);
        payroll.requestAdvance(advance);

        // Withdraw some more
        vm.warp(block.timestamp + 5 days); // Total 10 days, ~333 accrued
        vm.prank(alice);
        payroll.withdraw();

        // Release salary early (before full period)
        vm.warp(block.timestamp + 5 days); // Total 15 days, ~500 accrued

        vm.prank(owner);
        payroll.releaseSalary(alice);

        // Check that advance was partially or fully repaid
        (, , , , , uint256 outstanding, , ) = payroll.getEmployeeInfo(alice);
        // Outstanding should be 0 if accrued >= advance, or reduced
        assertTrue(outstanding == 0, "Advance should be repaid when possible");
    }

    // ========== UNDERFUNDING TESTS ==========

    function test_underfunding_noOverdraw_withdraw() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        // Fund only 100 ether (underfunded)
        token.approve(address(payroll), 100 ether);
        payroll.fund(100 ether);
        vm.stopPrank();

        // Accrue full salary
        vm.warp(block.timestamp + ONE_MONTH);

        (, , , uint256 totalAccrued, , , , ) = payroll.getEmployeeInfo(alice);
        assertApproxEqAbs(
            totalAccrued,
            1000 ether,
            1 ether,
            "Should accrue full salary"
        );

        vm.prank(alice);
        payroll.withdraw();

        uint256 balance = token.balanceOf(alice);

        // Should only receive what's in contract (100 ether), not full accrued
        assertEq(
            balance,
            100 ether,
            "Should only withdraw available contract balance"
        );
    }

    function test_underfunding_noOverdraw_advance() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        // Fund only 50 ether
        token.approve(address(payroll), 50 ether);
        payroll.fund(50 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days); // ~500 accrued

        (, , , , , , , uint256 available) = payroll.getEmployeeInfo(alice);
        uint256 advance = available / 2; // Would be ~250 ether

        vm.startPrank(alice);

        // Should fail - contract only has 50 ether
        vm.expectRevert("insufficient contract funds");
        payroll.requestAdvance(advance);

        // Can request up to contract balance
        payroll.requestAdvance(25 ether); // 50% of 50 ether available in contract

        vm.stopPrank();
    }

    function test_underfunding_releaseSalary() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        // Severely underfund
        token.approve(address(payroll), 50 ether);
        payroll.fund(50 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + ONE_MONTH);

        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(owner);
        payroll.releaseSalary(alice); // Should not revert

        uint256 balanceAfter = token.balanceOf(alice);

        // Should receive only what's available (50 ether)
        assertEq(
            balanceAfter - balanceBefore,
            50 ether,
            "Should receive clamped amount"
        );
    }

    function test_multipleEmployees_underfunding() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        payroll.registerEmployee(bob, 1000 ether);
        // Fund only enough for one employee
        token.approve(address(payroll), 1000 ether);
        payroll.fund(1000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + ONE_MONTH);

        // Alice withdraws first
        vm.prank(alice);
        payroll.withdraw();

        uint256 aliceBalance = token.balanceOf(alice);
        assertApproxEqAbs(
            aliceBalance,
            1000 ether,
            1 ether,
            "Alice gets full amount"
        );

        // Bob tries to withdraw but contract is empty - contract allows 0 withdrawal
        vm.prank(bob);
        payroll.withdraw(); // Will withdraw 0 (clamped to contract balance)

        uint256 bobBalance = token.balanceOf(bob);
        assertEq(bobBalance, 0, "Bob gets nothing - contract empty");
    }
}
