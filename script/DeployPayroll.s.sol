// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Payroll} from "src/Payroll.sol";
import {MockUSDC} from "test/mocks/MockUSDC.sol";

contract DeployPayroll is Script {
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 1e6;
    uint256 public constant RESERVED_PAYROLL_CYCLES = 3;
    uint256 public constant PAYROLL_INTERVAL_DAYS = 30;

    function run()
        external
        returns (
            Payroll,
            MockUSDC,
            uint256 reservedPayrollCycles,
            uint256 payrollIntervalInDays
        )
    {
        return deployContract();
    }

    function deployContract()
        public
        returns (
            Payroll,
            MockUSDC,
            uint256 reservedPayrollCycles,
            uint256 payrollIntervalInDays
        )
    {
        vm.startBroadcast();
        MockUSDC mockUSDC = new MockUSDC(INITIAL_SUPPLY);
        Payroll payroll = new Payroll(
            mockUSDC,
            RESERVED_PAYROLL_CYCLES,
            PAYROLL_INTERVAL_DAYS
        );
        vm.stopBroadcast();

        return (
            payroll,
            mockUSDC,
            RESERVED_PAYROLL_CYCLES,
            PAYROLL_INTERVAL_DAYS
        );
    }
}
