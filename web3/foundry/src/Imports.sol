// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract Token is ERC20("name", "symbol", 18) {}

import "@openzeppelin/contracts/access/Ownable.sol";

contract TestOz is Ownable(address(this)) {}

