// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Wallet} from "../src/Wallet.sol";

contract AuthTest is Test {
    Wallet public wallet;

    function setUp() public {
        wallet = new Wallet();
    }

    function testSetOwner() public {
        wallet.setOwner(address(1));
        assertEq(wallet.owner(), address(1));
    }

    function testRevertNotOwner() public {
        vm.expectRevert("caller is not owner");

        vm.prank(address(1));
        wallet.setOwner(address(1));
    }

    function testRevertNotOwnerAfterChange() public {
        // Correctly set owner to address(1)
        wallet.setOwner(address(1));

        // Call setOwner as address(1) multiple times
        vm.startPrank(address(1));
        wallet.setOwner(address(1));
        wallet.setOwner(address(1));
        wallet.setOwner(address(1));
        vm.stopPrank();

        // Try to setOwner as address(this)
        vm.expectRevert("caller is not owner");
        wallet.setOwner(address(1));
    }
}
