// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

interface ITokenController {
    function getMaxMintAmount() external returns(uint256);
}
