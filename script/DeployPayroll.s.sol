// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Payroll} from "src/Payroll.sol";
import {MockUSDC} from "test/mocks/MockUSDC.sol";

contract DeployPayroll is Script {
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 1e6;
    uint256 public constant RESERVED_PAYROLL_CYCLES = 3;

    /// @dev Production default. Override with the PAYROLL_INTERVAL_SECONDS
    /// environment variable to deploy a short-interval demo instance.
    uint256 public constant DEFAULT_PAYROLL_INTERVAL_SECONDS = 30 days;

    function run()
        external
        returns (
            Payroll,
            MockUSDC,
            uint256 reservedPayrollCycles,
            uint256 payrollIntervalInSeconds
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
            uint256 payrollIntervalInSeconds
        )
    {
        uint256 payrollInterval = vm.envOr(
            "PAYROLL_INTERVAL_SECONDS",
            DEFAULT_PAYROLL_INTERVAL_SECONDS
        );

        vm.startBroadcast();
        MockUSDC mockUSDC = new MockUSDC(INITIAL_SUPPLY);
        Payroll payroll = new Payroll(
            mockUSDC,
            RESERVED_PAYROLL_CYCLES,
            payrollInterval
        );
        vm.stopBroadcast();

        return (payroll, mockUSDC, RESERVED_PAYROLL_CYCLES, payrollInterval);
    }
}
