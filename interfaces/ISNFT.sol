// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

/**
 * @dev Interface of the TokensVesting contract.
 */
interface ISNFT {
	function mint(address to_) external returns (uint256);
}
