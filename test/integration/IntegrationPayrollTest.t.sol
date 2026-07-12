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
}
