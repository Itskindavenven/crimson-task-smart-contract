// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/PhiiCoin.sol";
import "../src/SalaryEWA.sol";

contract SalaryEWAIntegrationTest is Test {
    PhiiCoin token;
    SalaryEWA payroll;
    address owner = address(0xABCD);
    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);

    uint256 constant ONE_MONTH = 30 days;

    function setUp() public {
        vm.warp(1); // FIX: fully reset timestamp for this suite
        vm.startPrank(owner);
        token = new PhiiCoin(2_000_000 ether);
        payroll = new SalaryEWA(owner, IERC20(address(token)), ONE_MONTH);
        vm.stopPrank();
    }

    function test_multiEmployeeFlow_advances_withdraws_and_release() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        payroll.registerEmployee(bob, 2000 ether);
        payroll.registerEmployee(carol, 1500 ether);

        // Owner funds with 10k tokens
        token.approve(address(payroll), 10_000 ether);
        payroll.fund(10_000 ether);
        vm.stopPrank();

        // Warp 10 days: check accruals
        vm.warp(block.timestamp + 10 days);
        (, , , uint256 aliceAccrued,, , , uint256 aliceAvail) = payroll.getEmployeeInfo(alice);
        (, , , uint256 bobAccrued,, , , uint256 bobAvail) = payroll.getEmployeeInfo(bob);
        assertTrue(aliceAccrued > 0 && aliceAvail == aliceAccrued);
        assertTrue(bobAccrued > 0 && bobAvail == bobAccrued);

        // Alice requests advance up to 50% of available
        uint256 aliceAdvance = aliceAvail / 2;
        vm.prank(alice);
        payroll.requestAdvance(aliceAdvance);

        // Bob withdraws his available (no advance)
        vm.prank(bob);
        payroll.withdraw();

        // Alice cannot request another advance in same period
        vm.prank(alice);
        vm.expectRevert();
        payroll.requestAdvance(1 ether);

        // Warp to end of period and release salaries
        vm.warp(block.timestamp + (ONE_MONTH - 10 days) + 1);
        vm.startPrank(owner);
        payroll.releaseSalary(alice);
        payroll.releaseSalary(bob);
        payroll.releaseSalary(carol);
        vm.stopPrank();

        // After release, outstanding advances should be zero
        (, , , , , uint256 aliceOut, ,) = payroll.getEmployeeInfo(alice);
        (, , , , , uint256 bobOut, ,) = payroll.getEmployeeInfo(bob);
        assertEq(aliceOut, 0);
        assertEq(bobOut, 0);
    }

    function test_underfunding_during_release_and_withdraw() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        // Owner funds only 100 (underfund)
        token.approve(address(payroll), 100 ether);
        payroll.fund(100 ether);
        vm.stopPrank();

        // Warp to end of period so accrued large but contract small
        vm.warp(block.timestamp + ONE_MONTH);

        // Alice withdraw should clamp to contract balance
        vm.prank(alice);
        payroll.withdraw();
        uint256 balAfter = token.balanceOf(alice);
        assertTrue(balAfter <= 100 ether);

        // releaseSalary should not revert despite underfunding
        vm.startPrank(owner);
        payroll.releaseSalary(alice);
        vm.stopPrank();
    }
}
