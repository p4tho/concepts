// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Wallet {
    address payable public owner;

    constructor() {
        owner = payable(msg.sender);
    }

    receive() external payable {}

    modifier isOwner() {
        require(msg.sender == owner, "caller is not owner");
        _;
    }

    function withdraw(uint _amount) external isOwner {
        (bool sent, ) = payable(msg.sender).call{value: _amount}("");
        require(sent, "withdraw failed");
    }

    function setOwner(address _owner) external isOwner {
        owner = payable(_owner);
    }
}
