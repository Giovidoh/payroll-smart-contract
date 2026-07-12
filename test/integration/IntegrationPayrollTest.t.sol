// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployPayroll} from "script/DeployPayroll.s.sol";
import {Payroll} from "src/Payroll.sol";
import {MockUSDC} from "test/mocks/MockUSDC.sol";

contract IntegrationPayrollTest is Test {
    DeployPayroll public deployer;
    Payroll public payroll;
    MockUSDC public mockUSDC;
    address public OWNER;
    uint256 public constant DEPOSIT_AMOUNT = 100_000e6;
    address public ALICE = makeAddr("alice");
    uint256 public constant SALARY_1 = 500 * 1e6;
    address public DAVE = makeAddr("dave");
    uint256 public constant SALARY_2 = 1_000 * 1e6;
    address public CAROL = makeAddr("carol");
    uint256 public constant SALARY_3 = 10_000 * 1e6;
    address public BOB = makeAddr("bob");
    uint256 public constant SALARY_4 = 9_000 * 1e6;
    address public BECKA = makeAddr("becka");
    uint256 public constant SALARY_5 = 5_000 * 1e6;

    function setUp() external {
        deployer = new DeployPayroll();
        (payroll, mockUSDC) = deployer.run();
        OWNER = payroll.owner();
    }

    function testFullPayrollLifecycle() public {
        vm.startPrank(OWNER);

        // Add employees
        payroll.addEmployee(ALICE, SALARY_1);
        payroll.addEmployee(DAVE, SALARY_2);
        payroll.addEmployee(CAROL, SALARY_3);
        payroll.addEmployee(BOB, SALARY_4);

        // Add funds
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);

        // Run payroll
        payroll.runPayroll();

        // Assert
        assertEq(mockUSDC.balanceOf(ALICE), SALARY_1);
        assertEq(mockUSDC.balanceOf(DAVE), SALARY_2);
        assertEq(mockUSDC.balanceOf(CAROL), SALARY_3);
        assertEq(mockUSDC.balanceOf(BOB), SALARY_4);

        // Now let's:
        // 1. Increase an employee salary
        // 2. Cut another one's salary
        // 3. Fire one employee
        // 4. Add a new employee

        payroll.updateSalary(ALICE, SALARY_1 + 100);
        payroll.updateSalary(DAVE, SALARY_2 - 100);
        payroll.removeEmployee(CAROL);
        payroll.addEmployee(BECKA, SALARY_5);

        // Assert
        assertEq(payroll.getAllEmployees().length, 4); // Carol out, Becka in
        assertEq(payroll.getEmployeeExistence(CAROL), false);
        assertEq(payroll.getEmployeeExistence(BECKA), true);
        uint256 expectedTotal = (SALARY_1 + 100) +
            (SALARY_2 - 100) +
            SALARY_4 +
            SALARY_5;
        assertEq(payroll.getTotalSalaries(), expectedTotal);

        // Run payRoll again
        payroll.runPayroll();

        // Assert
        assertEq(mockUSDC.balanceOf(ALICE), SALARY_1 + (SALARY_1 + 100)); // both payments, cumulative
        assertEq(mockUSDC.balanceOf(DAVE), SALARY_2 + (SALARY_2 - 100));
        assertEq(mockUSDC.balanceOf(BOB), SALARY_4 * 2);
        assertEq(mockUSDC.balanceOf(BECKA), SALARY_5); // only paid once — wasn't around for cycle 1
        assertEq(mockUSDC.balanceOf(CAROL), SALARY_3); // still only their ONE payment from before removal — proves removal actually stopped future payment

        // Withdraw all available balance
        payroll.withdraw(payroll.getAvailableAmountForWithdrawal());

        assertEq(payroll.getAvailableAmountForWithdrawal(), 0); // drained exactly to the reserve line, nothing more

        vm.stopPrank();
    }
}
