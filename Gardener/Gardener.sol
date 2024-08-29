// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*####################################################
    @title Gardener Implementation
    @author BLOK Capital
#####################################################*/

contract TokenBoundAccount {
    address public accountOwner;

    modifier onlyOwner(address _owner) {
        require(_owner == accountOwner, "Caller is not the owner");
        _;
    } 

    receive() external payable {}
    fallback() external payable {}
}
