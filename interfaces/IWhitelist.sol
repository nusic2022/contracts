// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

/**
 * @dev Interface of the TokensVesting contract.
 */
interface IWhitelist {
	/**
		* @dev Returns the total amount of tokens in vesting plan.
		*/
	function total() external view returns (uint256);

	/**
		* @dev Returns the total releasable amount of tokens.
		*/
	function releasableAll() external view returns (uint256);

	/**
		* @dev Returns the releasable of given index
		*/
	function releasable(uint256 index_) external view returns (uint256);

	/**
		* @dev Returns the total released amount of tokens.
		*/
	function released() external view returns (uint256);

	/**
		* @dev Unlocks all releasable amount of tokens.
		*
		* Emits a {TokensReleased} event.
		*/
	function releaseAll() external;

	function setCrowdFundingParams(
		uint256 genesisTimestamp,
		uint256 tgeAmountRatio,
		uint256 cliff,
		uint256 duration,
		uint256 eraBasis,
		uint256 startTimestamp,
		uint256 endTimestamp,
		uint256 highest,
		uint256 lowest
	) external;

	function crowdFunding(uint256 amount, address referer) external;

	function getCurrentRate(uint256 amount) external view returns(uint256, uint256, uint256);

}
