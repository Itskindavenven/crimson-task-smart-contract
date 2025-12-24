// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/PhiiCoin.sol";
import "../src/SalaryEWA.sol";

contract AccrualTest is Test {
    PhiiCoin token;
    SalaryEWA payroll;
    address owner = address(0xABCD);
    address alice = address(0x1);
    uint256 constant ONE_MONTH = 30 days;

    function setUp() public {
        vm.warp(1); // reset timestamp so all periodStart = 1
        vm.startPrank(owner);
        token = new PhiiCoin(1_000_000 ether);
        payroll = new SalaryEWA(owner, IERC20(address(token)), ONE_MONTH);
        vm.stopPrank();
    }

    function test_zeroElapsedNoAccrual() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        vm.stopPrank();

        (, , uint256 periodStart, uint256 totalAccrued, , , , uint256 avail) = payroll.getEmployeeInfo(alice);
        assertEq(totalAccrued, 0);
        assertEq(avail, 0);
        assertTrue(periodStart > 0);
    }

    function test_linearAccrualOverTime() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1200 ether); // 1200 per period
        token.approve(address(payroll), 2000 ether);
        payroll.fund(2000 ether);
        vm.stopPrank();

        // after 15 days (half period), accrued ~600
        vm.warp(block.timestamp + (ONE_MONTH / 2));
        (, , , uint256 totalAccruedHalf, , , , uint256 availHalf) = payroll.getEmployeeInfo(alice);
        // approx half of 1200
        assertTrue(totalAccruedHalf >= 599 ether && totalAccruedHalf <= 601 ether);
        // available should equal accrued (no withdrawals/advances)
        assertEq(availHalf, totalAccruedHalf);

        // after full period (30 days) accrued ~= 1200
        vm.warp(block.timestamp + (ONE_MONTH / 2));
        (, , , uint256 totalAccruedFull, , , , uint256 availFull) = payroll.getEmployeeInfo(alice);
        assertTrue(totalAccruedFull >= 1199 ether && totalAccruedFull <= 1201 ether);
        assertEq(availFull, totalAccruedFull);
    }

    function test_withdrawal_updatesAccrualAndAvailable() public {
        vm.startPrank(owner);
        payroll.registerEmployee(alice, 1000 ether);
        token.approve(address(payroll), 2000 ether);
        payroll.fund(2000 ether);
        vm.stopPrank();

        // warp quarter month => accrued ~250
        vm.warp(block.timestamp + (ONE_MONTH / 4));

        vm.prank(alice);
        payroll.withdraw();

        (, , , uint256 totalAccrued, uint256 withdrawn, , , uint256 avail) = payroll.getEmployeeInfo(alice);
        // withdrawn > 0 and available = totalAccrued - withdrawn (should be zero after full withdraw)
        assertTrue(withdrawn > 0);
        assertEq(avail, (totalAccrued > withdrawn ? totalAccrued - withdrawn : 0));
    }
}
