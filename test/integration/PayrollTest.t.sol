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
    address public ALICE = makeAddr("alice");
    uint256 public constant SALARY_1 = 5 ether;
    address public DAVE = makeAddr("dave");
    uint256 public constant SALARY_2 = 10 ether;
    address public CAROL = makeAddr("carol");
    uint256 public constant SALARY_3 = 100 ether;
    address public BOB = makeAddr("bob");
    uint256 public constant SALARY_4 = 90 ether;

    /* Errors */
    error Payroll__EmployeeAlreadyExists();

    function setUp() public {
        deployer = new DeployPayroll();
        (payroll, mockUSDC) = deployer.run();
    }

    function testRevertsWhenEmployeeExists() public {
        // Arrange
        address owner = payroll.owner();
        vm.prank(owner);
        payroll.addEmployee(ALICE, SALARY_1);

        // Act / Assert
        vm.expectRevert(Payroll__EmployeeAlreadyExists.selector);
        vm.prank(owner);
        payroll.addEmployee(ALICE, SALARY_1);
    }
}
