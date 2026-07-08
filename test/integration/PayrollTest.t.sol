// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployPayroll} from "script/DeployPayroll.s.sol";
import {Payroll} from "src/Payroll.sol";
import {MockUSDC} from "test/mock/MockUSDC.sol";

contract PayrollTest is Test {
    DeployPayroll deployer;
    Payroll payroll;
    MockUSDC mockUSDC;
    address owner;
    address public ALICE = makeAddr("alice");
    uint256 public constant SALARY_1 = 500 * 1e6;
    address public DAVE = makeAddr("dave");
    uint256 public constant SALARY_2 = 1_000 * 1e6;
    address public CAROL = makeAddr("carol");
    uint256 public constant SALARY_3 = 10_000 * 1e6;
    address public BOB = makeAddr("bob");
    uint256 public constant SALARY_4 = 9_000 * 1e6;

    /* Errors */
    error Payroll__EmployeeAlreadyExists();
    error Payroll__InvalidAddress();
    error Payroll__SalaryMustBeGreaterThanZero();
    error Payroll__EmployeeDoesNotExist();

    function setUp() public {
        deployer = new DeployPayroll();
        (payroll, mockUSDC) = deployer.run();
        owner = payroll.owner();
    }

    /******************************************************************************
     *                                ADD EMPLOYEE                                *
     ******************************************************************************/
    function testRevertsWhenEmployeeExists() public {
        // Arrange
        vm.prank(owner);
        payroll.addEmployee(ALICE, SALARY_1);

        // Act / Assert
        vm.expectRevert(Payroll__EmployeeAlreadyExists.selector);
        vm.prank(owner);
        payroll.addEmployee(ALICE, SALARY_1);
    }

    function testRevertsWhenEmployeeAddressIsZero() public {
        // Arrange
        vm.prank(owner);

        // Act / Assert
        vm.expectRevert(Payroll__InvalidAddress.selector);
        payroll.addEmployee(address(0), SALARY_1);
    }

    function testRevertsWhenSalaryIsZero() public {
        // arrange
        vm.prank(owner);

        // Act / Assert
        vm.expectRevert(Payroll__SalaryMustBeGreaterThanZero.selector);
        payroll.addEmployee(ALICE, 0);
    }

    /******************************************************************************
     *                              REMOVE EMPLOYEE                               *
     ******************************************************************************/
    function testRevertsWhenEmployeeDoesNotExist() public {
        // Arrange
        vm.prank(owner);

        // Act / Assert
        vm.expectRevert(Payroll__EmployeeDoesNotExist.selector);
        payroll.removeEmployee(ALICE);
    }
}
