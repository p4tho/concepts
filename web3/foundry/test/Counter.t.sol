// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {stdError} from "forge-std/StdError.sol";
import {Test} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";

contract CounterTest is Test {
    Counter public counter;

    function setUp() public {
        counter = new Counter();
    }

    function testIncrement() public {
        counter.inc();
        assertEq(counter.count(), 1);
    }

    function testDecrement() public {
        counter.inc();
        counter.inc();
        counter.dec();
        assertEq(counter.count(), 1);
    }

    // uint can't be < 0
    function testRevertDec() public {
        vm.expectRevert(stdError.arithmeticError);
        counter.dec();
    }
}
