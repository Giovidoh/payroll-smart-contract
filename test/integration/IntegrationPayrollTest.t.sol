// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
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

    function testWithdrawRevertsWhenAmountIsGreaterThanAvailableFunds() public {
        vm.startPrank(OWNER);

        // Arrange
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);

        // Act / Assert
        vm.expectRevert(
            Payroll.Payroll__WithdrawalAmountExceedsAvailableFunds.selector
        );
        payroll.withdraw(DEPOSIT_AMOUNT * 2);

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
}
