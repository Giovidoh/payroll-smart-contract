// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Payroll} from "src/Payroll.sol";
import {MockUSDC} from "test/mocks/MockUSDC.sol";

contract DeployPayroll is Script {
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 1e6;

    function run() external returns (Payroll, MockUSDC) {
        return deployContract();
    }

    function deployContract() public returns (Payroll, MockUSDC) {
        vm.startBroadcast();
        MockUSDC mockUSDC = new MockUSDC(INITIAL_SUPPLY);
        Payroll payroll = new Payroll(mockUSDC);
        vm.stopBroadcast();

        return (payroll, mockUSDC);
    }
}
