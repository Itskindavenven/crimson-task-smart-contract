// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IEmployee - minimal interface for reading employee info from SalaryEWA
/// @notice Provides a stable view signature to be used by frontends / indexers (Ponder)
interface IEmployee {
    function getEmployeeInfo(address _employee) external view returns (
        uint256 monthlySalary,
        bool active,
        uint256 periodStart,
        uint256 totalAccrued,
        uint256 withdrawnInPeriod,
        uint256 outstandingAdvance,
        uint256 lastAdvancePeriod,
        uint256 availableToWithdraw
    );
}
