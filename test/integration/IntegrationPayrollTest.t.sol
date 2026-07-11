// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployPayroll} from "script/DeployPayroll.s.sol";
import {Payroll} from "src/Payroll.sol";
import {MockUSDC} from "test/mocks/MockUSDC.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

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

    /* Events */
    event FundsDeposited(address indexed owner, uint256 amount);
    event AmountWithdrawn(address indexed owner, uint256 amount);

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

    function setUp() external {
        deployer = new DeployPayroll();
        (payroll, mockUSDC) = deployer.run();
        OWNER = payroll.owner();
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
        emit FundsDeposited(OWNER, DEPOSIT_AMOUNT);
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
        emit AmountWithdrawn(OWNER, withdrawalAmount);
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
}
