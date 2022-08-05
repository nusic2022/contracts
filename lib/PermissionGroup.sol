//SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./Ownable.sol";
import "./Context.sol";

contract PermissionGroup is Ownable {
    // List of authorized address to perform some restricted actions
    mapping(address => bool) public operators;

    modifier onlyOperator() {
        require(operators[msg.sender], "PermissionGroup: not operator");
        _;
    }

    /**
     * @notice Adds an address as operator.
     */
    function addOperator(address operator) external onlyOwner {
        operators[operator] = true;
    }

    /**
    * @notice Removes an address as operator.
    */
    function removeOperator(address operator) external onlyOwner {
        operators[operator] = false;
    }
}