// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployPayroll} from "script/DeployPayroll.s.sol";
import {Payroll} from "src/Payroll.sol";
import {MockUSDC} from "test/mock/MockUSDC.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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

    /* Events */
    event NewEmployeeAdded(address indexed employee, uint256 salary);

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
        vm.expectRevert(Payroll.Payroll__EmployeeAlreadyExists.selector);
        vm.prank(owner);
        payroll.addEmployee(ALICE, SALARY_1);
    }

    function testRevertsWhenEmployeeAddressIsZero() public {
        // Arrange
        vm.prank(owner);

        // Act / Assert
        vm.expectRevert(Payroll.Payroll__InvalidAddress.selector);
        payroll.addEmployee(address(0), SALARY_1);
    }

    function testRevertsWhenSalaryIsZero() public {
        // Arrange
        vm.prank(owner);

        // Act / Assert
        vm.expectRevert(Payroll.Payroll__SalaryMustBeGreaterThanZero.selector);
        payroll.addEmployee(ALICE, 0);
    }

    function testEmployeeAddsToArray() public {
        // Arrange
        vm.startPrank(owner);

        // Act
        payroll.addEmployee(ALICE, SALARY_1);

        // Assert
        assertEq(payroll.getAllEmployees().length, 1);
        assertEq(payroll.getAllEmployees()[0].employeeAddress, ALICE);
        vm.stopPrank();
    }

    function testUpdatesMappings() public {
        // Arrange
        vm.startPrank(owner);

        // Act
        payroll.addEmployee(ALICE, SALARY_1);

        // Assert
        assertEq(payroll.getEmployeeIndex(ALICE), 0);
        assertEq(payroll.getEmployeeExistence(ALICE), true);
        vm.stopPrank();
    }

    function testSalaryAddsToTotalSalaries() public {
        // Arrange
        vm.prank(owner);
        uint256 startingTotalSalaries = payroll.getTotalSalaries();

        // Act
        vm.prank(owner);
        payroll.addEmployee(ALICE, SALARY_1);

        // Assert
        vm.prank(owner);
        uint256 endingTotalSalaries = payroll.getTotalSalaries();

        assertEq(startingTotalSalaries, 0);
        assertEq(endingTotalSalaries, SALARY_1);
    }

    function testAddingEmployeeEmits() public {
        // Arrange
        vm.prank(owner);

        // Act / Assert
        vm.expectEmit(true, false, false, true, address(payroll));
        emit NewEmployeeAdded(ALICE, SALARY_1);
        payroll.addEmployee(ALICE, SALARY_1);
    }

    function testOnlyOwnerCanAddEmployee() public {
        // First we try to add an employee using ALICE, it should revert
        // Arrange
        vm.prank(ALICE);

        // Act / Assert
        vm.expectRevert();
        payroll.addEmployee(BOB, SALARY_4);

        // Then we add an employee using the owner.
        vm.prank(owner);
        payroll.addEmployee(BOB, SALARY_4);
    }

    /******************************************************************************
     *                              REMOVE EMPLOYEE                               *
     ******************************************************************************/
    function testRevertsWhenEmployeeDoesNotExist() public {
        // Arrange
        vm.prank(owner);

        // Act / Assert
        vm.expectRevert(Payroll.Payroll__EmployeeDoesNotExist.selector);
        payroll.removeEmployee(ALICE);
    }

    function testOnlyOwnerCanRemoveEmployee() public {
        // Arrange
        vm.prank(owner);
        payroll.addEmployee(BOB, SALARY_4);

        // We try to remove BOB using ALICE, it should revert
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                ALICE
            )
        );
        payroll.removeEmployee(BOB);

        // We remove BOB using the owner.
        vm.prank(owner);
        payroll.removeEmployee(BOB);
    }
}
