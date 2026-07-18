// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployPayroll} from "script/DeployPayroll.s.sol";
import {Payroll} from "src/Payroll.sol";
import {MockUSDC} from "test/mocks/MockUSDC.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract PayrollTest is Test {
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

    /* Events */
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

    function setUp() public {
        deployer = new DeployPayroll();
        (payroll, mockUSDC) = deployer.run();
        OWNER = payroll.owner();
    }

    /******************************************************************************
     *                             OWNERSHIP TRANSFER                             *
     ******************************************************************************/
    function testTransferOwnershipDoesNotTakeEffectImmediately() public {
        // Act
        vm.prank(OWNER);
        payroll.transferOwnership(ALICE);

        // Assert
        assertEq(OWNER, payroll.owner());
    }

    function testNewOwnerMustAcceptOwnership() public {
        // Arrange
        vm.prank(OWNER);
        payroll.transferOwnership(ALICE);

        // Act
        vm.prank(ALICE);
        payroll.acceptOwnership();

        // Assert
        assertEq(ALICE, payroll.owner());
    }

    function testOldOwnerLosesAccessAfterAcceptance() public {
        // Arrange
        vm.prank(OWNER);
        payroll.transferOwnership(ALICE);
        vm.prank(ALICE);
        payroll.acceptOwnership();

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                OWNER
            )
        );
        vm.prank(OWNER);
        payroll.addEmployee(BOB, SALARY_1);
    }

    function testOnlyPendingOwnerCanAccept() public {
        // Arrange
        vm.prank(OWNER);
        payroll.transferOwnership(ALICE);

        // Act
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                OWNER
            )
        );
        vm.prank(OWNER);
        payroll.acceptOwnership();
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
        emit NewEmployeeAdded(ALICE, SALARY_1, block.timestamp);
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
        emit EmployeeRemoved(ALICE, block.timestamp);
        payroll.removeEmployee(ALICE);

        vm.stopPrank();
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
        emit SalaryUpdated(ALICE, SALARY_2, SALARY_1, block.timestamp);
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

    /******************************************************************************
     *                                  DEPOSIT                                   *
     ******************************************************************************/
    function testDepositRevertsWhenAmountIsZero() public {
        // Arrange
        vm.prank(OWNER);

        // Act / Assert
        vm.expectRevert(
            Payroll.Payroll__DepositAmountMustBeGreaterThanZero.selector
        );
        payroll.deposit(0);
    }

    function testDepositRevertsWhenAllowanceIsInsufficient() public {
        vm.startPrank(OWNER);
        // Arrange
        // No approve

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                address(payroll),
                0,
                DEPOSIT_AMOUNT
            )
        );
        payroll.deposit(DEPOSIT_AMOUNT);

        vm.stopPrank();
    }

    function testDepositRevertsWhenOwnerBalanceIsInsufficient() public {
        vm.startPrank(OWNER);

        // Arrange
        uint256 ownerBalance = mockUSDC.balanceOf(OWNER);
        uint256 excessiveAmount = ownerBalance * 2;
        mockUSDC.approve(address(payroll), excessiveAmount);

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                OWNER,
                ownerBalance,
                excessiveAmount
            )
        );
        payroll.deposit(excessiveAmount);

        vm.stopPrank();
    }

    function testOwnerCanSuccessfullyDeposit() public {
        vm.startPrank(OWNER);

        // Arrange
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);

        uint256 ownerStartingBalance = mockUSDC.balanceOf(OWNER);
        uint256 payrollStartingBalance = mockUSDC.balanceOf(address(payroll));

        // Act
        payroll.deposit(DEPOSIT_AMOUNT);

        // Assert
        uint256 ownerEndingBalance = mockUSDC.balanceOf(OWNER);
        uint256 payrollEndingBalance = mockUSDC.balanceOf(address(payroll));
        assertEq(ownerEndingBalance, ownerStartingBalance - DEPOSIT_AMOUNT);
        assertEq(payrollEndingBalance, payrollStartingBalance + DEPOSIT_AMOUNT);

        vm.stopPrank();
    }

    function testFundsDepositedEmits() public {
        vm.startPrank(OWNER);

        // Arrange
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);

        // Act / Assert
        vm.expectEmit(true, false, false, true, address(payroll));
        emit FundsDeposited(OWNER, DEPOSIT_AMOUNT, block.timestamp);
        payroll.deposit(DEPOSIT_AMOUNT);

        vm.stopPrank();
    }

    function testOnlyOwnerCanDeposit() public {
        // Arrange
        vm.prank(OWNER);
        mockUSDC.transfer(ALICE, DEPOSIT_AMOUNT);
        vm.prank(ALICE);
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);

        // Act / Assert
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                ALICE
            )
        );
        payroll.deposit(DEPOSIT_AMOUNT);
    }

    /******************************************************************************
     *                                  WITHDRAW                                  *
     ******************************************************************************/
    function testWithdrawRevertsWhenAmountIsZero() public {
        vm.startPrank(OWNER);

        // Arrange
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);

        // Act / Assert
        vm.expectRevert(
            Payroll.Payroll__WithdrawalAmountMustBeGreaterThanZero.selector
        );
        payroll.withdraw(0);

        vm.stopPrank();
    }

    function testWithdrawRevertsWhenAmountExceedsSurplusAboveReserve()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);

        // Arrange
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);

        // Act / Assert
        uint256 requiredReserve = payroll.getTotalSalaries() *
            payroll.getReservedPayrollCycles();
        uint256 surplus = DEPOSIT_AMOUNT - requiredReserve;
        vm.expectRevert(
            abi.encodeWithSelector(
                Payroll.Payroll__WithdrawalAmountExceedsAvailableFunds.selector,
                surplus
            )
        );
        payroll.withdraw(DEPOSIT_AMOUNT);

        vm.stopPrank();
    }

    function testWithdrawRevertsWhenContractBalanceIsBelowRequiredReserve()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);

        // Arrange
        // We have employees and no contract balance so contractBalance < requiredReserve

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Payroll.Payroll__WithdrawalAmountExceedsAvailableFunds.selector,
                0
            )
        );
        payroll.withdraw(DEPOSIT_AMOUNT);

        vm.stopPrank();
    }

    function testOwnerCanSuccessfullyWithdraw() public {
        vm.startPrank(OWNER);

        // Arrange
        uint256 ownerStartingBalance = mockUSDC.balanceOf(OWNER);
        uint256 payrollStartingBalance = mockUSDC.balanceOf(address(payroll));
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);

        // Act
        uint256 withdrawalAmount = DEPOSIT_AMOUNT / 3;
        payroll.withdraw(withdrawalAmount);

        // Assert
        uint256 ownerEndingBalance = mockUSDC.balanceOf(OWNER);
        uint256 payrollEndingBalance = mockUSDC.balanceOf(address(payroll));
        assertEq(
            ownerEndingBalance,
            ownerStartingBalance - DEPOSIT_AMOUNT + withdrawalAmount
        );
        assertEq(
            payrollEndingBalance,
            payrollStartingBalance + DEPOSIT_AMOUNT - withdrawalAmount
        );

        vm.stopPrank();
    }

    function testWithdrawSucceedsWithExactSurplusAboveReserve()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);

        // Arrange
        uint256 ownerStartingBalance = mockUSDC.balanceOf(OWNER);
        uint256 requiredReserve = payroll.getTotalSalaries() *
            payroll.getReservedPayrollCycles();
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);

        // Act
        uint256 exactSurplus = DEPOSIT_AMOUNT - requiredReserve;
        payroll.withdraw(exactSurplus);

        // Assert
        uint256 ownerEndingBalance = mockUSDC.balanceOf(OWNER);
        uint256 payrollEndingBalance = mockUSDC.balanceOf(address(payroll));
        assertEq(ownerEndingBalance, ownerStartingBalance - requiredReserve);
        assertEq(payrollEndingBalance, requiredReserve);

        vm.stopPrank();
    }

    function testWithdrawEverythingWhenNoEmployeesRemain() public {
        vm.startPrank(OWNER);

        //Arrange
        uint256 ownerStartingBalance = mockUSDC.balanceOf(OWNER);
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);

        // Act
        payroll.withdraw(DEPOSIT_AMOUNT);

        // Assert
        uint256 ownerEndingBalance = mockUSDC.balanceOf(OWNER);
        assertEq(ownerStartingBalance, ownerEndingBalance);
        assertEq(mockUSDC.balanceOf(address(payroll)), 0);

        vm.stopPrank();
    }

    function testWithdrawReservesScaleWithMultipleCycles()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);

        uint256 reservedPayrollCycles = 2;
        Payroll newPayroll = new Payroll(mockUSDC, reservedPayrollCycles);

        // Arrange
        newPayroll.addEmployee(ALICE, SALARY_1);
        newPayroll.addEmployee(DAVE, SALARY_2);
        newPayroll.addEmployee(CAROL, SALARY_3);
        newPayroll.addEmployee(BOB, SALARY_4);
        mockUSDC.approve(address(newPayroll), DEPOSIT_AMOUNT);
        newPayroll.deposit(DEPOSIT_AMOUNT);

        // Act
        uint256 requiredReserve = newPayroll.getTotalSalaries() *
            newPayroll.getReservedPayrollCycles();
        uint256 surplus = DEPOSIT_AMOUNT - requiredReserve;
        newPayroll.withdraw(surplus);

        // Assert
        assertEq(
            mockUSDC.balanceOf(address(newPayroll)),
            DEPOSIT_AMOUNT - surplus
        );

        vm.stopPrank();
    }

    function testAmountWithdrawnEmits() public {
        vm.startPrank(OWNER);

        // Arrange
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);

        // Act / Assert
        uint256 withdrawalAmount = DEPOSIT_AMOUNT / 2;
        vm.expectEmit(true, false, false, true, address(payroll));
        emit AmountWithdrawn(OWNER, withdrawalAmount, block.timestamp);
        payroll.withdraw(withdrawalAmount);

        vm.stopPrank();
    }

    function testOnlyOwnerCanWithdrawFunds() public {
        vm.startPrank(OWNER);
        // Arrange
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        // Act / Assert
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                ALICE
            )
        );
        payroll.withdraw(DEPOSIT_AMOUNT);
    }

    function testWithdrawSucceedsWhenReservedPayrollCyclesIsZero() public {
        vm.startPrank(OWNER);

        uint256 reservedPayrollCycles = 0;
        Payroll newPayroll = new Payroll(mockUSDC, reservedPayrollCycles);

        // Arrange
        newPayroll.addEmployee(ALICE, SALARY_1);
        newPayroll.addEmployee(DAVE, SALARY_2);
        newPayroll.addEmployee(CAROL, SALARY_3);
        newPayroll.addEmployee(BOB, SALARY_4);
        mockUSDC.approve(address(newPayroll), DEPOSIT_AMOUNT);
        newPayroll.deposit(DEPOSIT_AMOUNT);

        // Act
        newPayroll.withdraw(DEPOSIT_AMOUNT); // all salaries are multiplied by 0 (reservedPayrollCycles) so no subtraction needed.

        // Assert
        assertEq(mockUSDC.balanceOf(address(newPayroll)), 0);

        vm.stopPrank();
    }

    function testWithdrawRevertsWhenAmountIsOneUnitPastSurplus()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);

        // Arrange
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);

        uint256 requiredReserve = payroll.getTotalSalaries() *
            payroll.getReservedPayrollCycles();
        uint256 surplus = DEPOSIT_AMOUNT - requiredReserve;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Payroll.Payroll__WithdrawalAmountExceedsAvailableFunds.selector,
                surplus
            )
        );
        payroll.withdraw(surplus + 1); // one wei into committed funds

        vm.stopPrank();
    }

    /******************************************************************************
     *                                RUN PAYROLL                                 *
     ******************************************************************************/
    function testRunPayrollRevertsWhenContractBalanceIsInsufficient()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Payroll.Payroll__InsufficientBalanceForPayroll.selector,
                mockUSDC.balanceOf(address(payroll)),
                payroll.getTotalSalaries()
            )
        );
        payroll.runPayroll();

        vm.stopPrank();
    }

    function testRunPayrollSucceedsWithExactTotalSalaries()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);

        // Arrange
        uint256 totalSalaries = payroll.getTotalSalaries();
        mockUSDC.approve(address(payroll), totalSalaries);
        payroll.deposit(totalSalaries);
        uint256 payrollStartingBalance = mockUSDC.balanceOf(address(payroll));

        // Act
        payroll.runPayroll();
        uint256 payrollEndingBalance = mockUSDC.balanceOf(address(payroll));

        // Assert
        assertEq(payrollStartingBalance, payrollEndingBalance + totalSalaries);
        assertEq(mockUSDC.balanceOf(ALICE), payroll.getEmployee(ALICE).salary);
        assertEq(mockUSDC.balanceOf(DAVE), payroll.getEmployee(DAVE).salary);
        assertEq(mockUSDC.balanceOf(CAROL), payroll.getEmployee(CAROL).salary);
        assertEq(mockUSDC.balanceOf(BOB), payroll.getEmployee(BOB).salary);

        vm.stopPrank();
    }

    function testSalaryPaidEmitsForEachEmployee() public addMultipleEmployees {
        vm.startPrank(OWNER);

        // Arrange
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);

        // Act / Assert
        Payroll.Employee[] memory employees = payroll.getAllEmployees();
        for (uint256 i = 0; i < employees.length; i++) {
            vm.expectEmit(true, false, false, true, address(payroll));
            emit SalaryPaid(
                employees[i].employeeAddress,
                employees[i].salary,
                block.timestamp
            );
        }
        payroll.runPayroll();

        vm.stopPrank();
    }

    function testPayrollCompletedEmits() public addMultipleEmployees {
        vm.startPrank(OWNER);

        // Arrange
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);

        // Act / Assert
        Payroll.Employee[] memory employees = payroll.getAllEmployees();
        uint256 totalSalaries = payroll.getTotalSalaries();
        vm.expectEmit(false, false, false, true, address(payroll));
        emit PayrollCompleted(employees.length, totalSalaries, block.timestamp);
        payroll.runPayroll();

        vm.stopPrank();
    }

    function testOnlyOwnerCanRunPayroll() public addMultipleEmployees {
        // Arrange
        vm.startPrank(OWNER);
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        // Act / Assert
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                ALICE
            )
        );
        payroll.runPayroll();
    }

    function testRunPayrollRevertsWhenBalanceIsOneUnitShort()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);
        uint256 totalSalaries = payroll.getTotalSalaries();
        mockUSDC.approve(address(payroll), totalSalaries - 1);
        payroll.deposit(totalSalaries - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Payroll.Payroll__InsufficientBalanceForPayroll.selector,
                totalSalaries - 1,
                totalSalaries
            )
        );
        payroll.runPayroll();
        vm.stopPrank();
    }

    function testEmployeesStillRegisteredAfterPayroll()
        public
        addMultipleEmployees
    {
        vm.startPrank(OWNER);
        uint256 totalSalaries = payroll.getTotalSalaries();
        mockUSDC.approve(address(payroll), totalSalaries);
        payroll.deposit(totalSalaries);

        payroll.runPayroll();

        assertEq(payroll.getAllEmployees().length, 4);
        assertEq(payroll.getTotalSalaries(), totalSalaries); // unchanged — payroll doesn't remove obligations
        vm.stopPrank();
    }
}
