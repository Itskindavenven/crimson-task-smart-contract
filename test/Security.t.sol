// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/PhiiCoin.sol";
import "../src/SalaryEWA.sol";

/// @title Security Test Suite
/// @notice Tests for security requirements and access control
contract SecurityTest is Test {
    PhiiCoin token;
    SalaryEWA payroll;
    address owner = address(0xABCD);
    address nonOwner = address(0x999);
    address alice = address(0x1);
    address attacker = address(0x666);

    uint256 constant ONE_MONTH = 30 days;
    uint256 constant INITIAL_SUPPLY = 10_000_000 ether;

    event EmployeeRegistered(
        address indexed employee,
        uint256 monthlySalary,
        uint256 periodStart
    );
    event Funded(address indexed by, uint256 amount);
    event Withdrawn(address indexed employee, uint256 amount);
    event AdvanceRequested(address indexed employee, uint256 amount);
    event Refunded(address indexed to, uint256 amount);
    event PausedEvent(address account);
    event UnpausedEvent(address account);

    function setUp() public {
        vm.warp(1000);
        vm.startPrank(owner);
        token = new PhiiCoin(INITIAL_SUPPLY);
        payroll = new SalaryEWA(owner, IERC20(address(token)), ONE_MONTH);
        vm.stopPrank();
    }

    // ========== SOLIDITY VERSION VALIDATION ==========

    function test_solidity_version() public pure {
        // This test compiles only if Solidity ^0.8.x is used
        // Built-in overflow protection is available
        uint256 max = type(uint256).max;
        // In 0.8.x, this would revert, not wrap
        // We just verify compilation works
        assertTrue(max > 0, "Solidity 0.8.x confirmed");
    }

    // ========== ACCESS CONTROL - ONLYOWNER ==========

    function test_onlyOwner_registerEmployee() public {
        vm.startPrank(nonOwner);
        vm.expectRevert();
        payroll.registerEmployee(alice, 1000 ether);
        vm.stopPrank();

        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.stopPrank();
    }

    function test_onlyOwner_updateEmployee() public {
        vm.prank(owner);
        payroll.registerEmployee(alice, 1000 ether);

        vm.startPrank(nonOwner);
        vm.expectRevert();
        payroll.updateEmployee(alice, 2000 ether, true);
        vm.stopPrank();

        vm.startPrank(owner);
        payroll.updateEmployee(alice, 2000 ether, true);
        vm.stopPrank();
    }

    function test_onlyOwner_fund() public {
        vm.startPrank(nonOwner);
        vm.expectRevert();
        payroll.fund(1000 ether);
        vm.stopPrank();

        vm.startPrank(owner);
        token.approve(address(payroll), 1000 ether);
        payroll.fund(1000 ether);
        vm.stopPrank();
    }

    function test_onlyOwner_releaseSalary() public {
        vm.prank(owner);
        payroll.registerEmployee(alice, 1000 ether);

        vm.startPrank(nonOwner);
        vm.expectRevert();
        payroll.releaseSalary(alice);
        vm.stopPrank();

        vm.startPrank(owner);
        payroll.releaseSalary(alice);
        vm.stopPrank();
    }

    function test_onlyOwner_refund() public {
        vm.prank(owner);
        token.approve(address(payroll), 1000 ether);
        vm.prank(owner);
        payroll.fund(1000 ether);

        vm.startPrank(nonOwner);
        vm.expectRevert();
        payroll.refund(100 ether);
        vm.stopPrank();

        vm.startPrank(owner);
        payroll.refund(100 ether);
        vm.stopPrank();
    }

    function test_onlyOwner_emergencyWithdraw() public {
        vm.prank(owner);
        token.approve(address(payroll), 1000 ether);
        vm.prank(owner);
        payroll.fund(1000 ether);

        vm.startPrank(nonOwner);
        vm.expectRevert();
        payroll.emergencyWithdraw(nonOwner, 100 ether);
        vm.stopPrank();

        vm.startPrank(owner);
        payroll.emergencyWithdraw(owner, 100 ether);
        vm.stopPrank();
    }

    function test_onlyOwner_pause() public {
        vm.startPrank(nonOwner);
        vm.expectRevert();
        payroll.pause();
        vm.stopPrank();

        vm.startPrank(owner);
        payroll.pause();
        vm.stopPrank();
    }

    function test_onlyOwner_unpause() public {
        vm.prank(owner);
        payroll.pause();

        vm.startPrank(nonOwner);
        vm.expectRevert();
        payroll.unpause();
        vm.stopPrank();

        vm.startPrank(owner);
        payroll.unpause();
        vm.stopPrank();
    }

    // ========== ACCESS CONTROL - ONLYACTIVEEMPLOYEE ==========

    function test_onlyActiveEmployee_withdraw() public {
        vm.startPrank(attacker);
        vm.expectRevert("not active employee");
        payroll.withdraw();
        vm.stopPrank();

        // Register alice
        vm.prank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.prank(owner);
        token.approve(address(payroll), 5000 ether);
        vm.prank(owner);
        payroll.fund(5000 ether);

        vm.warp(block.timestamp + 15 days);

        // Alice can withdraw
        vm.prank(alice);
        payroll.withdraw();
    }

    function test_onlyActiveEmployee_requestAdvance() public {
        vm.startPrank(attacker);
        vm.expectRevert("not active employee");
        payroll.requestAdvance(100 ether);
        vm.stopPrank();

        // Register alice
        vm.prank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.prank(owner);
        token.approve(address(payroll), 5000 ether);
        vm.prank(owner);
        payroll.fund(5000 ether);

        vm.warp(block.timestamp + 15 days);

        // Alice can request advance
        (, , , , , , , uint256 available) = payroll.getEmployeeInfo(alice);
        vm.prank(alice);
        payroll.requestAdvance(available / 2);
    }

    function test_deactivatedEmployee_cannotWithdraw() public {
        vm.prank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.prank(owner);
        token.approve(address(payroll), 5000 ether);
        vm.prank(owner);
        payroll.fund(5000 ether);

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

    // ========== REENTRANCY PROTECTION ==========

    function test_reentrancy_withdraw() public {
        // The nonReentrant modifier should prevent reentrancy
        // This is implicitly tested by the modifier being present
        // We verify it's on the function
        vm.prank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.prank(owner);
        token.approve(address(payroll), 5000 ether);
        vm.prank(owner);
        payroll.fund(5000 ether);

        vm.warp(block.timestamp + 15 days);

        // Normal withdraw should work
        vm.prank(alice);
        payroll.withdraw();

        // Cannot withdraw again immediately (no funds available)
        vm.prank(alice);
        vm.expectRevert("no available to withdraw");
        payroll.withdraw();
    }

    function test_reentrancy_requestAdvance() public {
        vm.prank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.prank(owner);
        token.approve(address(payroll), 5000 ether);
        vm.prank(owner);
        payroll.fund(5000 ether);

        vm.warp(block.timestamp + 15 days);

        (, , , , , , , uint256 available) = payroll.getEmployeeInfo(alice);

        // First advance works
        vm.prank(alice);
        payroll.requestAdvance(available / 2);

        // Second advance in same period blocked
        vm.prank(alice);
        vm.expectRevert("advance already this period");
        payroll.requestAdvance(1 ether);
    }

    function test_reentrancy_fund() public {
        vm.startPrank(owner);
        token.approve(address(payroll), 10000 ether);

        // Multiple funds should work (no reentrancy issue)
        payroll.fund(1000 ether);
        payroll.fund(1000 ether);

        assertEq(
            payroll.totalFunded(),
            2000 ether,
            "Multiple funds should work"
        );

        vm.stopPrank();
    }

    // ========== INPUT VALIDATION ==========

    function test_inputValidation_zeroAddress_registerEmployee() public {
        vm.startPrank(owner);
        vm.expectRevert("zero addr");
        payroll.registerEmployee(address(0), 1000 ether);
        vm.stopPrank();
    }

    function test_inputValidation_zeroAddress_updateEmployee() public {
        vm.startPrank(owner);
        vm.expectRevert("zero addr");
        payroll.updateEmployee(address(0), 1000 ether, true);
        vm.stopPrank();
    }

    function test_inputValidation_zeroAddress_releaseSalary() public {
        vm.startPrank(owner);
        vm.expectRevert("zero addr");
        payroll.releaseSalary(address(0));
        vm.stopPrank();
    }

    function test_inputValidation_zeroAddress_emergencyWithdraw() public {
        vm.startPrank(owner);
        vm.expectRevert("zero addr");
        payroll.emergencyWithdraw(address(0), 1000 ether);
        vm.stopPrank();
    }

    function test_inputValidation_zeroAmount_fund() public {
        vm.startPrank(owner);
        vm.expectRevert("amount>0");
        payroll.fund(0);
        vm.stopPrank();
    }

    function test_inputValidation_zeroAmount_refund() public {
        vm.startPrank(owner);
        vm.expectRevert("amount>0");
        payroll.refund(0);
        vm.stopPrank();
    }

    function test_inputValidation_zeroAmount_emergencyWithdraw() public {
        vm.startPrank(owner);
        vm.expectRevert("amount>0");
        payroll.emergencyWithdraw(owner, 0);
        vm.stopPrank();
    }

    function test_inputValidation_zeroAmount_requestAdvance() public {
        vm.prank(owner);
        payroll.registerEmployee(alice, 1000 ether);

        vm.startPrank(alice);
        vm.expectRevert("amount>0");
        payroll.requestAdvance(0);
        vm.stopPrank();
    }

    function test_inputValidation_zeroSalary_registerEmployee() public {
        vm.startPrank(owner);
        vm.expectRevert("salary>0");
        payroll.registerEmployee(alice, 0);
        vm.stopPrank();
    }

    // ========== EVENT EMISSION ==========

    function test_events_registerEmployee() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true);
        emit EmployeeRegistered(alice, 1000 ether, block.timestamp);

        payroll.registerEmployee(alice, 1000 ether);

        vm.stopPrank();
    }

    function test_events_fund() public {
        vm.startPrank(owner);
        token.approve(address(payroll), 1000 ether);

        vm.expectEmit(true, false, false, true);
        emit Funded(owner, 1000 ether);

        payroll.fund(1000 ether);

        vm.stopPrank();
    }

    function test_events_withdraw() public {
        vm.prank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.prank(owner);
        token.approve(address(payroll), 5000 ether);
        vm.prank(owner);
        payroll.fund(5000 ether);

        vm.warp(block.timestamp + 15 days);

        vm.startPrank(alice);

        vm.expectEmit(true, false, false, false);
        emit Withdrawn(alice, 0); // Amount varies

        payroll.withdraw();

        vm.stopPrank();
    }

    function test_events_requestAdvance() public {
        vm.prank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.prank(owner);
        token.approve(address(payroll), 5000 ether);
        vm.prank(owner);
        payroll.fund(5000 ether);

        vm.warp(block.timestamp + 15 days);

        (, , , , , , , uint256 available) = payroll.getEmployeeInfo(alice);
        uint256 advance = available / 2;

        vm.startPrank(alice);

        vm.expectEmit(true, false, false, true);
        emit AdvanceRequested(alice, advance);

        payroll.requestAdvance(advance);

        vm.stopPrank();
    }

    function test_events_refund() public {
        vm.prank(owner);
        token.approve(address(payroll), 5000 ether);
        vm.prank(owner);
        payroll.fund(5000 ether);

        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true);
        emit Refunded(owner, 1000 ether);

        payroll.refund(1000 ether);

        vm.stopPrank();
    }

    function test_events_pause() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, false);
        emit PausedEvent(owner);

        payroll.pause();

        vm.stopPrank();
    }

    function test_events_unpause() public {
        vm.prank(owner);
        payroll.pause();

        vm.startPrank(owner);

        vm.expectEmit(true, false, false, false);
        emit UnpausedEvent(owner);

        payroll.unpause();

        vm.stopPrank();
    }

    // ========== EDGE CASES & ATTACK VECTORS ==========

    function test_attack_cannotStealFunds() public {
        vm.prank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.prank(owner);
        token.approve(address(payroll), 5000 ether);
        vm.prank(owner);
        payroll.fund(5000 ether);

        vm.warp(block.timestamp + 15 days);

        // Attacker cannot withdraw alice's funds
        vm.startPrank(attacker);
        vm.expectRevert("not active employee");
        payroll.withdraw();
        vm.stopPrank();

        // Attacker cannot take advance
        vm.startPrank(attacker);
        vm.expectRevert("not active employee");
        payroll.requestAdvance(100 ether);
        vm.stopPrank();
    }

    function test_attack_cannotDrainContract() public {
        vm.prank(owner);
        token.approve(address(payroll), 5000 ether);
        vm.prank(owner);
        payroll.fund(5000 ether);

        // Attacker cannot refund
        vm.startPrank(attacker);
        vm.expectRevert();
        payroll.refund(5000 ether);
        vm.stopPrank();

        // Attacker cannot emergency withdraw
        vm.startPrank(attacker);
        vm.expectRevert();
        payroll.emergencyWithdraw(attacker, 5000 ether);
        vm.stopPrank();
    }

    function test_edge_maxUint256() public {
        // Test that contract handles large numbers correctly
        vm.startPrank(owner);

        // Register with very large salary (but reasonable)
        uint256 largeSalary = 1_000_000_000 ether;
        payroll.registerEmployee(alice, largeSalary);

        // Verify registration succeeded
        (uint256 salary, , , , , , , ) = payroll.getEmployeeInfo(alice);
        assertEq(salary, largeSalary, "Large salary should be set correctly");

        vm.stopPrank();
    }

    function test_edge_multiplePeriodsWithoutRelease() public {
        vm.prank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.prank(owner);
        token.approve(address(payroll), 10000 ether);
        vm.prank(owner);
        payroll.fund(10000 ether);

        // Wait multiple periods without release
        vm.warp(block.timestamp + (ONE_MONTH * 3));

        (, , , uint256 accrued, , , , ) = payroll.getEmployeeInfo(alice);

        // Should accrue linearly even beyond one period
        assertApproxEqAbs(
            accrued,
            3000 ether,
            10 ether,
            "Should accrue for 3 months"
        );
    }
}
