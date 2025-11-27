// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice SalaryEWA - Earned Wage Access payroll contract (Foundry-ready, safe mode)
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract SalaryEWA is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public immutable payPeriodSeconds; // e.g., 30 days

    struct Employee {
        uint256 monthlySalary;        // salary per pay period (smallest units)
        uint256 periodStart;          // start timestamp of current pay period
        bool active;                  // active flag
        uint256 withdrawnInPeriod;    // amount withdrawn within current pay period
        uint256 outstandingAdvance;   // outstanding advance (debt)
        uint256 lastAdvancePeriod;    // period index when last advance taken
    }

    mapping(address => Employee) public employees;
    address[] public employeeList;
    mapping(address => bool) private inList;

    // accounting
    uint256 public totalFunded;
    uint256 public totalWithdrawn;
    uint256 public totalRefunded;

    // events
    event EmployeeRegistered(address indexed employee, uint256 monthlySalary, uint256 periodStart);
    event EmployeeUpdated(address indexed employee, uint256 monthlySalary, bool active);
    event Funded(address indexed by, uint256 amount);
    event Withdrawn(address indexed employee, uint256 amount);
    event AdvanceRequested(address indexed employee, uint256 amount);
    event AdvanceRepaid(address indexed employee, uint256 amountRepaid, uint256 remainingAdvance);
    event Refunded(address indexed to, uint256 amount);
    event PausedEvent(address account);
    event UnpausedEvent(address account);

    constructor(
        address _owner,
        IERC20 _token,
        uint256 _payPeriodSeconds
    ) 
        Ownable(_owner) 
    {
        require(address(_token) != address(0), "zero token");
        require(_payPeriodSeconds > 0, "payPeriod>0");

        token = _token;
        payPeriodSeconds = _payPeriodSeconds;
    }


    // ---------- Modifiers ----------
    modifier onlyActiveEmployee() {
        require(employees[msg.sender].active, "not active employee");
        _;
    }

    // ---------- Owner / Employer ----------
    function registerEmployee(address _employee, uint256 _monthlySalary) external onlyOwner whenNotPaused {
        require(_employee != address(0), "zero addr");
        require(_monthlySalary > 0, "salary>0");

        Employee storage e = employees[_employee];

        if (!inList[_employee]) {
            employeeList.push(_employee);
            inList[_employee] = true;
            e.periodStart = block.timestamp; // new employee: start period now
            e.lastAdvancePeriod = type(uint256).max; // sentinel: allow first advance
        }


        e.monthlySalary = _monthlySalary;
        e.active = true;

        emit EmployeeRegistered(_employee, _monthlySalary, e.periodStart);
    }

    function updateEmployee(address _employee, uint256 _monthlySalary, bool _active) external onlyOwner whenNotPaused {
        require(_employee != address(0), "zero addr");
        Employee storage e = employees[_employee];
        require(e.periodStart != 0, "not registered");
        e.monthlySalary = _monthlySalary;
        e.active = _active;
        emit EmployeeUpdated(_employee, _monthlySalary, _active);
    }

    function fund(uint256 _amount) external nonReentrant onlyOwner whenNotPaused {
        require(_amount > 0, "amount>0");
        totalFunded += _amount;
        token.safeTransferFrom(msg.sender, address(this), _amount);
        emit Funded(msg.sender, _amount);
    }

    /// Owner releases salary for _employee (payday settlement)
    function releaseSalary(address _employee) external nonReentrant onlyOwner whenNotPaused {
        require(_employee != address(0), "zero addr");
        Employee storage e = employees[_employee];
        require(e.periodStart != 0, "not registered");

        uint256 totalAccrued = _totalAccruedSincePeriodStart(_employee);
        uint256 remainingAccrued = 0;
        if (totalAccrued > e.withdrawnInPeriod) {
            remainingAccrued = totalAccrued - e.withdrawnInPeriod;
        } else {
            remainingAccrued = 0;
        }

        uint256 contractBal = token.balanceOf(address(this));

        // First use remainingAccrued to repay outstandingAdvance
        if (e.outstandingAdvance > 0) {
            if (remainingAccrued >= e.outstandingAdvance) {
                // fully repay
                uint256 repay = e.outstandingAdvance;
                remainingAccrued -= repay;
                e.outstandingAdvance = 0;
                emit AdvanceRepaid(_employee, repay, 0);
            } else {
                // partially repay
                uint256 repay = remainingAccrued;
                e.outstandingAdvance = e.outstandingAdvance - repay;
                remainingAccrued = 0;
                emit AdvanceRepaid(_employee, repay, e.outstandingAdvance);
            }
        }

        // Pay remainingAccrued to employee if contract has balance
        if (remainingAccrued > 0 && contractBal > 0) {
            uint256 payout = remainingAccrued;
            if (payout > contractBal) payout = contractBal; // clamp underfunding
            token.safeTransfer(_employee, payout);
            totalWithdrawn += payout;
            emit Withdrawn(_employee, payout);
        }

        // Reset period start and counters for next pay period
        e.periodStart = block.timestamp;
        e.withdrawnInPeriod = 0;
        e.lastAdvancePeriod = type(uint256).max;
    }

    /// Refund only free funds (not locked)
    function refund(uint256 _amount) external nonReentrant onlyOwner whenNotPaused {
        require(_amount > 0, "amount>0");
        uint256 contractBal = token.balanceOf(address(this));
        require(_amount <= contractBal, "amount>balance");
        uint256 locked = _computeLockedAmount();
        require(contractBal - locked >= _amount, "insufficient free funds");
        totalRefunded += _amount;
        token.safeTransfer(msg.sender, _amount);
        emit Refunded(msg.sender, _amount);
    }

    function emergencyWithdraw(address _to, uint256 _amount) external nonReentrant onlyOwner {
        require(_to != address(0), "zero addr");
        require(_amount > 0, "amount>0");
        uint256 contractBal = token.balanceOf(address(this));
        require(_amount <= contractBal, "amount>balance");
        uint256 locked = _computeLockedAmount();
        require(contractBal - locked >= _amount, "exceeds free funds");
        totalRefunded += _amount;
        token.safeTransfer(_to, _amount);
        emit Refunded(_to, _amount);
    }

    function pause() external onlyOwner {
        _pause();
        emit PausedEvent(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit UnpausedEvent(msg.sender);
    }

    // ---------- Employee actions ----------
    /// Withdraw available accrued (net of withdrawnInPeriod and outstandingAdvance)
    function withdraw() external nonReentrant onlyActiveEmployee whenNotPaused {
        address emp = msg.sender;
        Employee storage e = employees[emp];

        uint256 totalAccrued = _totalAccruedSincePeriodStart(emp);
        uint256 available = 0;
        if (totalAccrued > e.withdrawnInPeriod + e.outstandingAdvance) {
            available = totalAccrued - e.withdrawnInPeriod - e.outstandingAdvance;
        } else {
            available = 0;
        }
        require(available > 0, "no available to withdraw");

        uint256 contractBal = token.balanceOf(address(this));
        if (available > contractBal) available = contractBal; // underfunding guard

        e.withdrawnInPeriod += available;
        totalWithdrawn += available;
        token.safeTransfer(emp, available);
        emit Withdrawn(emp, available);
    }

    /// Request advance up to 50% of currently available (totalAccrued - withdrawnInPeriod - outstandingAdvance)
    function requestAdvance(uint256 _amount) external nonReentrant onlyActiveEmployee whenNotPaused {
        require(_amount > 0, "amount>0");
        address emp = msg.sender;
        Employee storage e = employees[emp];
        require(e.periodStart != 0, "not registered");

        uint256 totalAccrued = _totalAccruedSincePeriodStart(emp);
        // available to be considered for advance: totalAccrued - withdrawnInPeriod - outstandingAdvance
        uint256 availableForAdvance = 0;
        if (totalAccrued > e.withdrawnInPeriod + e.outstandingAdvance) {
            availableForAdvance = totalAccrued - e.withdrawnInPeriod - e.outstandingAdvance;
        } else {
            availableForAdvance = 0;
        }
        require(availableForAdvance > 0, "no accrued to advance from");

        uint256 maxAdvance = availableForAdvance / 2; // 50%
        require(_amount <= maxAdvance, "exceeds 50% of current available");

        uint256 currentPeriodIndex = _payPeriodIndex(emp);
        require(e.lastAdvancePeriod != currentPeriodIndex, "advance already this period");

        uint256 contractBal = token.balanceOf(address(this));
        require(_amount <= contractBal, "insufficient contract funds");

        e.outstandingAdvance += _amount;
        e.lastAdvancePeriod = currentPeriodIndex;

        totalWithdrawn += _amount;
        token.safeTransfer(emp, _amount);
        emit AdvanceRequested(emp, _amount);
    }

    // ---------- Views & helpers ----------
    function getEmployeeInfo(address _employee) external view returns (
        uint256 monthlySalary,
        bool active,
        uint256 periodStart,
        uint256 totalAccrued,
        uint256 withdrawnInPeriod,
        uint256 outstandingAdvance,
        uint256 lastAdvancePeriod,
        uint256 availableToWithdraw
    ) {
        Employee storage e = employees[_employee];
        monthlySalary = e.monthlySalary;
        active = e.active;
        periodStart = e.periodStart;
        totalAccrued = _totalAccruedSincePeriodStart(_employee);
        withdrawnInPeriod = e.withdrawnInPeriod;
        outstandingAdvance = e.outstandingAdvance;
        lastAdvancePeriod = e.lastAdvancePeriod;

        if (totalAccrued > e.withdrawnInPeriod + e.outstandingAdvance) {
            availableToWithdraw = totalAccrued - e.withdrawnInPeriod - e.outstandingAdvance;
        } else {
            availableToWithdraw = 0;
        }
    }

    function employeesCount() external view returns (uint256) {
        return employeeList.length;
    }

    // total accrued since periodStart (not subtracting withdrawn)
    function _totalAccruedSincePeriodStart(address _employee) internal view returns (uint256) {
        Employee storage e = employees[_employee];
        if (e.periodStart == 0 || e.monthlySalary == 0) return 0;
        uint256 elapsed = block.timestamp - e.periodStart;
        if (elapsed == 0) return 0;
        uint256 accrued = (e.monthlySalary * elapsed) / payPeriodSeconds;
        return accrued;
    }

    // per-employee period index (0-based)
    function _payPeriodIndex(address _employee) internal view returns (uint256) {
        Employee storage e = employees[_employee];
        if (e.periodStart == 0) return 0;
        return (block.timestamp - e.periodStart) / payPeriodSeconds;
    }

    // compute locked funds = sum(remainingAccrued + outstandingAdvance) for all employees
    function _computeLockedAmount() internal view returns (uint256 locked) {
        locked = 0;
        for (uint256 i = 0; i < employeeList.length; i++) {
            address emp = employeeList[i];
            Employee storage e = employees[emp];
            if (!e.active) continue;
            uint256 totalAccrued = _totalAccruedSincePeriodStart(emp);
            uint256 remainingAccrued = 0;
            if (totalAccrued > e.withdrawnInPeriod) {
                remainingAccrued = totalAccrued - e.withdrawnInPeriod;
            } else {
                remainingAccrued = 0;
            }
            // add remaining accrued (what must still be paid) + outstanding advance (debt)
            locked += remainingAccrued + e.outstandingAdvance;
        }
    }
}
