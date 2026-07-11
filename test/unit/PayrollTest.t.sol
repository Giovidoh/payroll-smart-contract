// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployPayroll} from "script/DeployPayroll.s.sol";
import {Payroll} from "src/Payroll.sol";
import {MockUSDC} from "test/mocks/MockUSDC.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PayrollTest is Test {
    DeployPayroll public deployer;
    Payroll public payroll;
    MockUSDC public mockUSDC;
    address public OWNER;
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
    event EmployeeRemoved(address indexed employee);
    event SalaryUpdated(
        address indexed employee,
        uint256 newSalary,
        uint256 oldSalary
    );

    function setUp() public {
        deployer = new DeployPayroll();
        (payroll, mockUSDC) = deployer.run();
        OWNER = payroll.owner();
    }

    /******************************************************************************
     *                                ADD EMPLOYEE                                *
     ******************************************************************************/
    function testRevertsWhenEmployeeExists() public {
        // Arrange
        vm.prank(OWNER);
        payroll.addEmployee(ALICE, SALARY_1);

        // Act / Assert
        vm.expectRevert(Payroll.Payroll__EmployeeAlreadyExists.selector);
        vm.prank(OWNER);
        payroll.addEmployee(ALICE, SALARY_1);
    }

    function testRevertsWhenEmployeeAddressIsZero() public {
        // Arrange
        vm.prank(OWNER);

        // Act / Assert
        vm.expectRevert(Payroll.Payroll__InvalidAddress.selector);
        payroll.addEmployee(address(0), SALARY_1);
    }

    function testRevertsWhenSalaryIsZero() public {
        // Arrange
        vm.prank(OWNER);

        // Act / Assert
        vm.expectRevert(Payroll.Payroll__SalaryMustBeGreaterThanZero.selector);
        payroll.addEmployee(ALICE, 0);
    }

    function testEmployeeAddsToArray() public {
        // Arrange
        vm.startPrank(OWNER);

        // Act
        payroll.addEmployee(ALICE, SALARY_1);

        // Assert
        assertEq(payroll.getAllEmployees().length, 1);
        assertEq(payroll.getAllEmployees()[0].employeeAddress, ALICE);
        vm.stopPrank();
    }

    function testUpdatesMappings() public {
        // Arrange
        vm.startPrank(OWNER);

        // Act
        payroll.addEmployee(ALICE, SALARY_1);

        // Assert
        assertEq(payroll.getEmployeeIndex(ALICE), 0);
        assertEq(payroll.getEmployeeExistence(ALICE), true);
        vm.stopPrank();
    }

    function testSalaryAddsToTotalSalaries() public {
        // Arrange
        vm.prank(OWNER);
        uint256 startingTotalSalaries = payroll.getTotalSalaries();

        // Act
        vm.prank(OWNER);
        payroll.addEmployee(ALICE, SALARY_1);

        // Assert
        vm.prank(OWNER);
        uint256 endingTotalSalaries = payroll.getTotalSalaries();

        assertEq(startingTotalSalaries, 0);
        assertEq(endingTotalSalaries, SALARY_1);
    }

    function testAddingEmployeeEmits() public {
        // Arrange
        vm.prank(OWNER);

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
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                ALICE
            )
        );
        payroll.addEmployee(BOB, SALARY_4);

        // Then we add an employee using the OWNER.
        vm.prank(OWNER);
        payroll.addEmployee(BOB, SALARY_4);
    }

    /******************************************************************************
     *                              REMOVE EMPLOYEE                               *
     ******************************************************************************/
    function testRevertsWhenEmployeeDoesNotExist() public {
        // Arrange
        vm.prank(OWNER);

        // Act / Assert
        vm.expectRevert(Payroll.Payroll__EmployeeDoesNotExist.selector);
        payroll.removeEmployee(ALICE);
    }

    function testSalarySubtractsFromTotalSalaries()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);

        // Arrange
        uint256 startingTotalSalaries = payroll.getTotalSalaries();

        // Act
        payroll.removeEmployee(ALICE);

        // Assert
        uint256 endingTotalSalaries = payroll.getTotalSalaries();
        assertEq(startingTotalSalaries - SALARY_1, endingTotalSalaries);

        vm.stopPrank();
    }

    function testIndexMappingClearedAfterRemoval() public addMultipleEmployees {
        vm.startPrank(OWNER);

        // Arrange
        uint256 startingIndex = payroll.getEmployeeIndex(BOB);

        // Act
        payroll.removeEmployee(BOB);

        // Assert
        // Since BOB's index is 3 when added, if removed it should not exist anymore
        uint256 endingIndex = payroll.getEmployeeIndex(BOB);
        assertEq(startingIndex, 3);
        assertEq(endingIndex, 0);

        vm.stopPrank();
    }

    function testExistenceMappingClearedAfterRemoval() public {
        vm.startPrank(OWNER);

        // Arrange
        payroll.addEmployee(ALICE, SALARY_1);

        // Act
        payroll.removeEmployee(ALICE);

        // Assert
        assertEq(payroll.getEmployeeExistence(ALICE), false);

        vm.stopPrank();
    }

    function testRemovingEmployeeEmits() public {
        vm.startPrank(OWNER);

        // Arrange
        payroll.addEmployee(ALICE, SALARY_1);

        // Act / Assert
        vm.expectEmit(true, false, false, false, address(payroll));
        emit EmployeeRemoved(ALICE);
        payroll.removeEmployee(ALICE);

        vm.stopPrank();
    }

    /**
     * @dev This modifier adds multiple salaries to the payroll contract.
     */
    modifier addMultipleEmployees() {
        vm.startPrank(OWNER);
        payroll.addEmployee(ALICE, SALARY_1);
        payroll.addEmployee(DAVE, SALARY_2);
        payroll.addEmployee(CAROL, SALARY_3);
        payroll.addEmployee(BOB, SALARY_4);
        vm.stopPrank();
        _;
    }

    function testRemovesFirstEmployeeWhenMultipleExist()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);

        // Act
        payroll.removeEmployee(ALICE);

        // Assert
        assertEq(payroll.getEmployeeExistence(ALICE), false);
        assertEq(payroll.getAllEmployees().length, 3);
        assertEq(payroll.getAllEmployees()[0].employeeAddress, BOB);
        assertEq(payroll.getEmployeeIndex(BOB), 0);

        vm.stopPrank();
    }

    function testRemovesMiddleEmployeeWhenMultipleExist()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);

        // Act
        payroll.removeEmployee(DAVE);

        // Assert
        assertEq(payroll.getEmployeeExistence(DAVE), false);
        assertEq(payroll.getAllEmployees().length, 3);
        assertEq(payroll.getAllEmployees()[1].employeeAddress, BOB);
        assertEq(payroll.getEmployeeIndex(BOB), 1);

        vm.stopPrank();
    }

    function testRemovesLastEmployeeWhenMultipleExist()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);

        // Act
        payroll.removeEmployee(BOB);

        // Assert
        assertEq(payroll.getEmployeeExistence(BOB), false);
        assertEq(payroll.getAllEmployees().length, 3);
        // Confirm nobody moved — Alice, Dave, Carol stayed at their original indices
        assertEq(payroll.getAllEmployees()[0].employeeAddress, ALICE);
        assertEq(payroll.getAllEmployees()[1].employeeAddress, DAVE);
        assertEq(payroll.getAllEmployees()[2].employeeAddress, CAROL);

        vm.stopPrank();
    }

    function testRemovesOnlyEmployeeAndEmptiesArray() public {
        vm.startPrank(OWNER);

        // Arrange
        payroll.addEmployee(ALICE, SALARY_1);

        // Act
        payroll.removeEmployee(ALICE);

        // Assert
        assertEq(payroll.getEmployeeExistence(ALICE), false);
        assertEq(payroll.getAllEmployees().length, 0);

        vm.stopPrank();
    }

    function testOnlyOwnerCanRemoveEmployee() public {
        // Arrange
        vm.prank(OWNER);
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

        // We remove BOB using the OWNER.
        vm.prank(OWNER);
        payroll.removeEmployee(BOB);
    }

    /*************************************************************************************
     *                              UPDATE EMPLOYEE SALARY                               *
     *************************************************************************************/
    function testUpdateRevertsWhenEmployeeDoesNotExist() public {
        vm.startPrank(OWNER);

        // Act / Assert
        vm.expectRevert(Payroll.Payroll__EmployeeDoesNotExist.selector);
        payroll.updateSalary(ALICE, SALARY_1);

        vm.stopPrank();
    }

    function testUpdateRevertsWhenSalaryIsZero() public {
        vm.startPrank(OWNER);

        // Arrange
        payroll.addEmployee(ALICE, SALARY_1);

        // Act / Assert
        vm.expectRevert(Payroll.Payroll__SalaryMustBeGreaterThanZero.selector);
        payroll.updateSalary(ALICE, 0);

        vm.stopPrank();
    }

    function testUpdateSalaryRevertsWhenValueUnchanged() public {
        vm.startPrank(OWNER);

        // Arrange
        payroll.addEmployee(ALICE, SALARY_1);

        // Act / Assert
        vm.expectRevert(Payroll.Payroll__SalaryUnchanged.selector);
        payroll.updateSalary(ALICE, SALARY_1);

        vm.stopPrank();
    }

    function testUpdatesSalary() public {
        vm.startPrank(OWNER);

        // Arrange
        payroll.addEmployee(ALICE, SALARY_1);

        // Act
        payroll.updateSalary(ALICE, SALARY_2);

        // Assert
        assertEq(payroll.getEmployee(ALICE).salary, SALARY_2);

        vm.stopPrank();
    }

    function testUpdatesTotalSalariesOnPayCut() public addMultipleEmployees {
        vm.startPrank(OWNER);

        // Act
        payroll.updateSalary(ALICE, 25);

        // Assert
        uint256 newTotalSalaries = payroll.getTotalSalaries();
        uint256 aggregatedSalaries = payroll.getEmployee(ALICE).salary +
            payroll.getEmployee(DAVE).salary +
            payroll.getEmployee(CAROL).salary +
            payroll.getEmployee(BOB).salary;

        assertEq(aggregatedSalaries, newTotalSalaries);

        vm.stopPrank();
    }

    function testUpdatesTotalSalariesOnPayIncrease()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);

        // Act
        payroll.updateSalary(ALICE, 5e9);

        // Assert
        uint256 newTotalSalaries = payroll.getTotalSalaries();
        uint256 aggregatedSalaries = payroll.getEmployee(ALICE).salary +
            payroll.getEmployee(DAVE).salary +
            payroll.getEmployee(CAROL).salary +
            payroll.getEmployee(BOB).salary;

        assertEq(aggregatedSalaries, newTotalSalaries);

        vm.stopPrank();
    }

    function testSalaryUpdatedEmits() public {
        vm.startPrank(OWNER);

        // Arrange
        payroll.addEmployee(ALICE, SALARY_1);

        // Act / Assert
        vm.expectEmit(true, false, false, true, address(payroll));
        emit SalaryUpdated(ALICE, SALARY_2, SALARY_1);
        payroll.updateSalary(ALICE, SALARY_2);

        vm.stopPrank();
    }

    function testOnlyOwnerCanUpdateSalary() public addMultipleEmployees {
        // Arrange
        vm.prank(ALICE);

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                ALICE
            )
        );
        payroll.updateSalary(BOB, SALARY_1);

        vm.prank(OWNER);
        payroll.updateSalary(BOB, SALARY_1);
    }

    /******************************************************************************
     *                                GET EMPLOYEE                                *
     ******************************************************************************/
    function testGetEmployeeRevertsForUnauthorizedCaller() public {
        // Arrange
        vm.prank(BOB);

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Payroll
                    .Payroll__OnlyOwnerAndConcernedEmployeeCanAccess
                    .selector,
                BOB
            )
        );
        payroll.getEmployee(ALICE);
    }

    function testGetEmployeeRevertsWhenEmployeeDoesNotExist() public {
        // Arrange
        vm.prank(OWNER);

        // Act / Assert
        vm.expectRevert(Payroll.Payroll__EmployeeDoesNotExist.selector);
        payroll.getEmployee(ALICE);
    }

    function testGetEmployeeSucceedsForOwner() public {
        // Arrange
        vm.prank(OWNER);
        payroll.addEmployee(ALICE, SALARY_1);

        // Act
        vm.prank(OWNER);
        Payroll.Employee memory employee = payroll.getEmployee(ALICE);

        // Assert
        assertEq(employee.employeeAddress, ALICE);
    }

    function testGetEmployeeSucceedsForTheEmployeeThemself() public {
        // Arrange
        vm.prank(OWNER);
        payroll.addEmployee(ALICE, SALARY_1);

        // Act
        vm.prank(ALICE);
        Payroll.Employee memory employee = payroll.getEmployee(ALICE);

        // Assert
        assertEq(employee.employeeAddress, ALICE);
    }
}
