// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Payroll} from "src/Payroll.sol";
import {MockUSDC} from "test/mocks/MockUSDC.sol";

/**
 * @notice Measures how runPayroll's gas cost scales with the number of employees.
 *
 * The point is to separate the fixed cost of calling runPayroll (interval check,
 * balance read, timestamp write, PayrollCompleted) from the marginal cost of each
 * employee paid. Dividing total gas by headcount conflates the two and overstates
 * the per-employee cost at small headcounts.
 *
 * Every measurement is preceded by vm.cool on the payroll contract, the token and
 * each recipient. Without it, a second runPayroll inside the same test function
 * reuses the access list warmed by the first and reports roughly a third of what a
 * real transaction costs — the EVM charges 2600 gas for a cold account and 2100 for
 * a cold storage slot, and every employee contributes both.
 *
 * Two regimes are reported per headcount, because they differ substantially:
 *   - first cycle: every recipient's token balance goes from zero to non-zero,
 *     the expensive SSTORE case (20 000 gas instead of 2 900).
 *   - steady state: recipients already hold a balance, the normal case for any
 *     payroll after the first.
 *
 * Reported totals include the 21 000 gas intrinsic cost of a transaction, so they
 * are comparable with what a block explorer shows for a real runPayroll.
 */
contract PayrollGasScalingTest is Test {
    uint256 public constant SALARY = 100e6;
    uint256 public constant DEPOSIT = 500_000e6;
    uint256 public constant INITIAL_SUPPLY = 1_000_000e6;
    uint256 public constant RESERVED_CYCLES = 3;
    uint256 public constant INTERVAL = 30 days;
    uint256 public constant TX_BASE_COST = 21_000;

    uint256[] internal headcounts;

    MockUSDC internal token;
    address[] internal employees;

    function setUp() public {
        headcounts = new uint256[](6);
        headcounts[0] = 1;
        headcounts[1] = 2;
        headcounts[2] = 5;
        headcounts[3] = 10;
        headcounts[4] = 20;
        headcounts[5] = 50;
    }

    /// @dev Fresh contract per headcount so no state leaks between measurements.
    function _deploy(uint256 employeeCount) internal returns (Payroll payroll) {
        token = new MockUSDC(INITIAL_SUPPLY);
        payroll = new Payroll(token, RESERVED_CYCLES, INTERVAL);

        delete employees;
        for (uint256 i = 0; i < employeeCount; i++) {
            address employee = address(
                uint160(uint256(keccak256(abi.encode("employee", i))))
            );
            employees.push(employee);
            payroll.addEmployee(employee, SALARY);
        }

        token.approve(address(payroll), DEPOSIT);
        payroll.deposit(DEPOSIT);
    }

    /// @dev Puts every account runPayroll will touch back into the cold state
    /// an actual transaction would find them in.
    function _coolEverything(Payroll payroll) internal {
        vm.cool(address(payroll));
        vm.cool(address(token));
        for (uint256 i = 0; i < employees.length; i++) {
            vm.cool(employees[i]);
        }
    }

    function _measure(Payroll payroll) internal returns (uint256 gasUsed) {
        _coolEverything(payroll);
        uint256 before = gasleft();
        payroll.runPayroll();
        gasUsed = before - gasleft() + TX_BASE_COST;
    }

    function testGasScalingOfRunPayroll() public {
        console.log(
            "effectif | premier cycle | regime etabli | cout marginal en regime etabli"
        );

        uint256 previousSteady;
        uint256 previousCount;

        for (uint256 i = 0; i < headcounts.length; i++) {
            uint256 count = headcounts[i];
            Payroll payroll = _deploy(count);

            vm.warp(block.timestamp + INTERVAL + 1);
            uint256 firstCycle = _measure(payroll);

            vm.warp(block.timestamp + INTERVAL + 1);
            uint256 steadyState = _measure(payroll);

            string memory marginal = "-";
            if (i > 0) {
                marginal = string.concat(
                    vm.toString(
                        (steadyState - previousSteady) / (count - previousCount)
                    ),
                    " gas / salarie supplementaire"
                );
            }

            console.log(
                string.concat(
                    vm.toString(count),
                    " | ",
                    vm.toString(firstCycle),
                    " | ",
                    vm.toString(steadyState),
                    " | ",
                    marginal
                )
            );

            previousSteady = steadyState;
            previousCount = count;
        }
    }
}
