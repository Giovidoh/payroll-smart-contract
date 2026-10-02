// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployPayroll} from "script/DeployPayroll.s.sol";
import {Payroll} from "src/Payroll.sol";
import {PayrollRelay} from "src/PayrollRelay.sol";
import {IReceiver} from "src/cre/IReceiver.sol";
import {IERC165} from "src/cre/IERC165.sol";
import {ReceiverTemplate} from "src/cre/ReceiverTemplate.sol";
import {MockUSDC} from "test/mocks/MockUSDC.sol";

contract PayrollRelayTest is Test {
    Payroll public payroll;
    MockUSDC public mockUSDC;
    PayrollRelay public relay;
    uint256 public payrollInterval;
    address public OWNER;

    address public FORWARDER = makeAddr("forwarder");
    address public ALICE = makeAddr("alice");
    uint256 public constant SALARY = 1_000e6;
    uint256 public constant DEPOSIT_AMOUNT = 100_000e6;

    event PayrollTriggered(uint256 requestedAt, uint256 timestamp);

    function setUp() public {
        DeployPayroll deployer = new DeployPayroll();
        (payroll, mockUSDC, , payrollInterval) = deployer.run();
        OWNER = payroll.owner();

        vm.startPrank(OWNER);
        payroll.addEmployee(ALICE, SALARY);
        mockUSDC.approve(address(payroll), DEPOSIT_AMOUNT);
        payroll.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        relay = new PayrollRelay(FORWARDER, payroll);
    }

    function report(uint256 requestedAt) internal pure returns (bytes memory) {
        return abi.encode(requestedAt);
    }

    function warpToNextPayroll() internal {
        vm.warp(payroll.getLastPayrollTimestamp() + payrollInterval);
    }

    /* Constructor */

    function testConstructorRejectsZeroForwarder() public {
        vm.expectRevert(ReceiverTemplate.InvalidForwarderAddress.selector);
        new PayrollRelay(address(0), payroll);
    }

    function testConstructorRejectsZeroPayroll() public {
        vm.expectRevert(
            PayrollRelay.PayrollRelay__InvalidPayrollAddress.selector
        );
        new PayrollRelay(FORWARDER, Payroll(address(0)));
    }

    function testGettersReturnConfiguration() public view {
        assertEq(relay.getPayroll(), address(payroll));
        assertEq(relay.getForwarderAddress(), FORWARDER);
    }

    /* ERC165: the forwarder checks it before delivering a report */

    function testSupportsReceiverInterface() public view {
        assertTrue(relay.supportsInterface(type(IReceiver).interfaceId));
        assertTrue(relay.supportsInterface(type(IERC165).interfaceId));
        assertFalse(relay.supportsInterface(0xffffffff));
    }

    /* onReport */

    function testOnReportRunsPayrollWhenDue() public {
        warpToNextPayroll();

        vm.expectEmit(false, false, false, true, address(relay));
        emit PayrollTriggered(block.timestamp, block.timestamp);
        vm.prank(FORWARDER);
        relay.onReport("", report(block.timestamp));

        assertEq(mockUSDC.balanceOf(ALICE), SALARY);
        assertEq(payroll.getLastPayrollTimestamp(), block.timestamp);
    }

    function testOnReportRevertsWhenCallerIsNotForwarder() public {
        warpToNextPayroll();
        address stranger = makeAddr("stranger");

        vm.expectRevert(
            abi.encodeWithSelector(
                ReceiverTemplate.InvalidSender.selector,
                stranger,
                FORWARDER
            )
        );
        vm.prank(stranger);
        relay.onReport("", report(block.timestamp));
    }

    function testOnReportRevertsWhenPayrollIsNotDue() public {
        uint256 dueAt = payroll.getLastPayrollTimestamp() + payrollInterval;

        vm.expectRevert(
            abi.encodeWithSelector(
                Payroll.Payroll__TooEarlyForNextPayroll.selector,
                dueAt
            )
        );
        vm.prank(FORWARDER);
        relay.onReport("", report(block.timestamp));

        assertEq(mockUSDC.balanceOf(ALICE), 0);
    }

    function testOnReportRejectsRequestFromTheFuture() public {
        warpToNextPayroll();
        uint256 future = block.timestamp + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                PayrollRelay.PayrollRelay__RequestFromTheFuture.selector,
                future,
                block.timestamp
            )
        );
        vm.prank(FORWARDER);
        relay.onReport("", report(future));
    }

    function testSecondReportInSameIntervalReverts() public {
        warpToNextPayroll();
        vm.startPrank(FORWARDER);
        relay.onReport("", report(block.timestamp));

        vm.expectRevert(
            abi.encodeWithSelector(
                Payroll.Payroll__TooEarlyForNextPayroll.selector,
                block.timestamp + payrollInterval
            )
        );
        relay.onReport("", report(block.timestamp));
        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(ALICE), SALARY);
    }

    /* Forwarder switch: simulation forwarder first, production forwarder after */

    function testOwnerCanSwitchForwarder() public {
        address production = makeAddr("productionForwarder");
        relay.setForwarderAddress(production);
        assertEq(relay.getForwarderAddress(), production);

        warpToNextPayroll();
        vm.expectRevert(
            abi.encodeWithSelector(
                ReceiverTemplate.InvalidSender.selector,
                FORWARDER,
                production
            )
        );
        vm.prank(FORWARDER);
        relay.onReport("", report(block.timestamp));
    }

    function testNonOwnerCannotSwitchForwarder() public {
        vm.prank(ALICE);
        vm.expectRevert();
        relay.setForwarderAddress(ALICE);
    }
}
