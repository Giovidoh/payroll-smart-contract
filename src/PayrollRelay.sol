// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {ReceiverTemplate} from "./cre/ReceiverTemplate.sol";
import {Payroll} from "./Payroll.sol";

/**
 * @title PayrollRelay
 * @notice Receives the reports of the Chainlink CRE workflow and triggers the
 * payroll. CRE does not call arbitrary functions: it delivers a signed report
 * to a receiver through the Chainlink Forwarder, and this relay turns that
 * report into a `runPayroll()` call.
 * @dev The relay grants no right the public does not already have:
 * `runPayroll()` is open to anyone, and the Payroll contract alone enforces the
 * interval and the balance. A report arriving too early reverts with
 * `Payroll__TooEarlyForNextPayroll`, so the schedule stays on-chain.
 */
contract PayrollRelay is ReceiverTemplate {
    // State variables
    Payroll private immutable i_payroll;

    // Events
    event PayrollTriggered(uint256 requestedAt, uint256 timestamp);

    // Errors
    error PayrollRelay__InvalidPayrollAddress();
    error PayrollRelay__RequestFromTheFuture(uint256 requestedAt, uint256 now);

    constructor(
        address forwarderAddress,
        Payroll payroll
    ) ReceiverTemplate(forwarderAddress) {
        if (address(payroll) == address(0)) {
            revert PayrollRelay__InvalidPayrollAddress();
        }
        i_payroll = payroll;
    }

    function getPayroll() external view returns (address) {
        return address(i_payroll);
    }

    /// @dev The report carries the DON time at which the workflow decided the
    /// payroll was due. A report dated in the future is rejected.
    function _processReport(bytes calldata report) internal override {
        uint256 requestedAt = abi.decode(report, (uint256));
        if (requestedAt > block.timestamp) {
            revert PayrollRelay__RequestFromTheFuture(
                requestedAt,
                block.timestamp
            );
        }

        i_payroll.runPayroll();

        emit PayrollTriggered(requestedAt, block.timestamp);
    }
}
