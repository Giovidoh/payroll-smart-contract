// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Payroll} from "src/Payroll.sol";
import {PayrollRelay} from "src/PayrollRelay.sol";

/// @notice Deploys the CRE relay of an existing Payroll contract.
/// @dev Both addresses come from the environment, never from this file:
/// PAYROLL_ADDRESS, and FORWARDER_ADDRESS — the MockKeystoneForwarder for
/// broadcast simulations, the KeystoneForwarder once the workflow is deployed.
/// The owner can switch later with setForwarderAddress().
contract DeployPayrollRelay is Script {
    function run() external returns (PayrollRelay relay) {
        address forwarder = vm.envAddress("FORWARDER_ADDRESS");
        Payroll payroll = Payroll(vm.envAddress("PAYROLL_ADDRESS"));

        vm.startBroadcast();
        relay = new PayrollRelay(forwarder, payroll);
        vm.stopBroadcast();
    }
}
