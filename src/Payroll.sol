// Contract elements should be laid out in the following order:
// Pragma statements
// Import statements
// Events
// Errors
// Interfaces
// Libraries
// Contracts

// Inside each contract, library or interface, use the following order:
// Type declarations
// State variables
// Events
// Errors
// Modifiers
// Functions

// Functions should be grouped according to their visibility and ordered:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Payroll is Ownable2Step {
    // Type declarations
    struct Employee {
        address employeeAddress;
        uint256 salary;
    }

    // State variables
    IERC20 private immutable i_stablecoin;
    uint256 private immutable i_reservedPayrollCycles;
    Employee[] private s_employees;
    mapping(address => uint256) private s_employeeAddressToIndex;
    mapping(address => bool) private s_employeeAddressToExistence;
    uint256 private s_totalSalaries;

    // Events
    event NewEmployeeAdded(
        address indexed employee,
        uint256 salary,
        uint256 timestamp
    );
    event EmployeeRemoved(address indexed employee, uint256 timestamp);
    event SalaryUpdated(
        address indexed employee,
        uint256 newSalary,
        uint256 oldSalary,
        uint256 timestamp
    );
    event FundsDeposited(
        address indexed owner,
        uint256 amount,
        uint256 timestamp
    );
    event AmountWithdrawn(
        address indexed owner,
        uint256 amount,
        uint256 timestamp
    );
    event SalaryPaid(
        address indexed employee,
        uint256 salary,
        uint256 timestamp
    );
    event PayrollCompleted(
        uint256 numberOfEmployeesPaid,
        uint256 totalAmountPaid,
        uint256 timestamp
    );

    // Errors
    error Payroll__EmployeeAlreadyExists();
    error Payroll__InvalidAddress();
    error Payroll__SalaryMustBeGreaterThanZero();
    error Payroll__EmployeeDoesNotExist();
    error Payroll__OnlyOwnerAndConcernedEmployeeCanAccess(
        address senderAddress
    );
    error Payroll__SalaryUnchanged();
    error Payroll__DepositAmountMustBeGreaterThanZero();
    error Payroll__TransferFromFailed();
    error Payroll__WithdrawalAmountMustBeGreaterThanZero();
    error Payroll__WithdrawalAmountExceedsAvailableFunds(
        uint256 availableFunds
    );
    error Payroll__WithdrawalFailed();
    error Payroll__InsufficientBalanceForPayroll(
        uint256 contractBalance,
        uint256 totalSalaries
    );
    error Payroll__SalaryTransferFailed(address employeeAddress);

    constructor(
        IERC20 stablecoin,
        uint256 reservedPayrollCycles
    ) Ownable(msg.sender) {
        i_stablecoin = stablecoin;
        i_reservedPayrollCycles = reservedPayrollCycles;
    }

    function addEmployee(
        address employeeAddress,
        uint256 salary
    ) external onlyOwner {
        // Check if the employee already exists
        if (s_employeeAddressToExistence[employeeAddress]) {
            revert Payroll__EmployeeAlreadyExists();
        }
        // Check if employeeAddress is address(0)
        if (employeeAddress == address(0)) {
            revert Payroll__InvalidAddress();
        }
        // Check if salary equals 0
        if (salary == 0) {
            revert Payroll__SalaryMustBeGreaterThanZero();
        }

        // Add new employee to the table
        Employee memory newEmployee = Employee(employeeAddress, salary);
        s_employees.push(newEmployee);

        // Map the employee's address to index in the table
        s_employeeAddressToIndex[employeeAddress] = s_employees.length - 1;

        // Map existence
        s_employeeAddressToExistence[employeeAddress] = true;

        // Add employee's salary to total salaries
        s_totalSalaries += salary;

        emit NewEmployeeAdded(
            newEmployee.employeeAddress,
            newEmployee.salary,
            block.timestamp
        );
    }

    function removeEmployee(address employeeAddress) external onlyOwner {
        // Check if the employee exists
        if (!s_employeeAddressToExistence[employeeAddress]) {
            revert Payroll__EmployeeDoesNotExist();
        }

        uint256 employeeIndex = s_employeeAddressToIndex[employeeAddress];
        uint256 lastIndex = s_employees.length - 1;
        Employee memory employeeToRemove = s_employees[employeeIndex];
        Employee memory lastEmployee = s_employees[lastIndex];

        // Substract the salary from total salaries
        s_totalSalaries -= s_employees[employeeIndex].salary;

        // Swap-and-pop (For O(1)) while updating last employee address
        if (employeeIndex != lastIndex) {
            s_employees[employeeIndex] = lastEmployee;
            s_employeeAddressToIndex[
                lastEmployee.employeeAddress
            ] = employeeIndex;
        }
        s_employees.pop();

        // Delete removed index
        delete s_employeeAddressToIndex[employeeAddress];

        // Clear existence
        delete (s_employeeAddressToExistence[employeeAddress]);

        emit EmployeeRemoved(employeeToRemove.employeeAddress, block.timestamp);
    }

    function updateSalary(
        address employeeAddress,
        uint256 newSalary
    ) external onlyOwner {
        if (!s_employeeAddressToExistence[employeeAddress]) {
            revert Payroll__EmployeeDoesNotExist();
        }
        if (newSalary == 0) {
            revert Payroll__SalaryMustBeGreaterThanZero();
        }

        uint256 employeeIndex = s_employeeAddressToIndex[employeeAddress];
        Employee memory employee = s_employees[employeeIndex];
        uint256 oldSalary = employee.salary;

        if (newSalary == oldSalary) {
            revert Payroll__SalaryUnchanged();
        }

        s_employees[employeeIndex].salary = newSalary;

        // if (newSalary >= oldSalary) {
        //     s_totalSalaries += newSalary - oldSalary;
        // } else {
        //     s_totalSalaries -= oldSalary - newSalary;
        // }
        //
        // The code commented just above can be used to be more explicit but consumes more gas
        unchecked {
            s_totalSalaries += newSalary - oldSalary;
        }

        emit SalaryUpdated(
            employee.employeeAddress,
            newSalary,
            oldSalary,
            block.timestamp
        );
    }

    function deposit(uint256 amount) external onlyOwner {
        if (amount == 0) {
            revert Payroll__DepositAmountMustBeGreaterThanZero();
        }

        // Transfer from owner's wallet
        bool success = i_stablecoin.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        // unreachable with OZ's modern ERC20, kept for defense against non-standard tokens
        if (!success) {
            revert Payroll__TransferFromFailed();
        }

        emit FundsDeposited(msg.sender, amount, block.timestamp);
    }

    function withdraw(uint256 amount) external onlyOwner {
        if (amount == 0) {
            revert Payroll__WithdrawalAmountMustBeGreaterThanZero();
        }

        uint256 requiredReserve = s_totalSalaries * i_reservedPayrollCycles; // Total amount locked that the employer can't remove for now
        uint256 contractBalance = i_stablecoin.balanceOf(address(this));

        if (contractBalance < requiredReserve) {
            revert Payroll__WithdrawalAmountExceedsAvailableFunds(0);
        }

        uint256 availableSurplus = contractBalance - requiredReserve;
        if (amount > availableSurplus) {
            revert Payroll__WithdrawalAmountExceedsAvailableFunds(
                availableSurplus
            );
        }

        bool success = i_stablecoin.transfer(msg.sender, amount);
        // unreachable with OZ's modern ERC20, kept for defense against non-standard tokens
        if (!success) {
            revert Payroll__WithdrawalFailed();
        }

        emit AmountWithdrawn(msg.sender, amount, block.timestamp);
    }

    function runPayroll() external onlyOwner {
        uint256 contractBalance = i_stablecoin.balanceOf(address(this));
        if (contractBalance < s_totalSalaries) {
            revert Payroll__InsufficientBalanceForPayroll(
                contractBalance,
                s_totalSalaries
            );
        }

        Employee[] memory allEmployees = s_employees;
        for (uint256 i = 0; i < allEmployees.length; i++) {
            address employeeAddress = allEmployees[i].employeeAddress;
            uint256 salary = allEmployees[i].salary;

            bool success = i_stablecoin.transfer(employeeAddress, salary);
            if (!success) {
                revert Payroll__SalaryTransferFailed(employeeAddress);
            }

            emit SalaryPaid(employeeAddress, salary, block.timestamp);
        }

        emit PayrollCompleted(
            allEmployees.length,
            s_totalSalaries,
            block.timestamp
        );
    }

    /* Getter functions */
    function getAllEmployees()
        external
        view
        onlyOwner
        returns (Employee[] memory)
    {
        return s_employees;
    }

    function getEmployee(
        address employeeAddress
    ) external view returns (Employee memory) {
        // It's important checking the access control before any other checks.
        // Thus an attacker can't guess which addresses exist or not.
        if (msg.sender != owner() && msg.sender != employeeAddress) {
            revert Payroll__OnlyOwnerAndConcernedEmployeeCanAccess(msg.sender);
        }
        if (!s_employeeAddressToExistence[employeeAddress]) {
            revert Payroll__EmployeeDoesNotExist();
        }

        uint256 employeeIndex = s_employeeAddressToIndex[employeeAddress];
        return s_employees[employeeIndex];
    }

    // This is for testing purposes, it's an implementation detail not useful to stakeholders.
    // But here it's restricted to owner only so no high security issue.
    // stdStorage should replace it later.
    function getEmployeeIndex(
        address employeeAddress
    ) external view onlyOwner returns (uint256) {
        return s_employeeAddressToIndex[employeeAddress];
    }

    function getEmployeeExistence(
        address employeeAddress
    ) external view onlyOwner returns (bool) {
        return s_employeeAddressToExistence[employeeAddress];
    }

    function getTotalSalaries() external view onlyOwner returns (uint256) {
        return s_totalSalaries;
    }

    function getReservedPayrollCycles() external view returns (uint256) {
        return i_reservedPayrollCycles;
    }

    function getAvailableAmountForWithdrawal() external view returns (uint256) {
        uint256 requiredReserve = s_totalSalaries * i_reservedPayrollCycles;
        uint256 contractBalance = i_stablecoin.balanceOf(address(this));
        if (contractBalance < requiredReserve) {
            revert Payroll__WithdrawalAmountExceedsAvailableFunds(0);
        }

        return i_stablecoin.balanceOf(address(this)) - requiredReserve;
    }
}
