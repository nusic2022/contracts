// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

interface ISupportProofTokenFactory {
	function getSPTokenBalanceOfUser(uint256 tokenId_, address user_) external view returns (uint256);
	function getSPTokenTotalSupply(uint256 tokenId_) external view returns(uint256);
	function getAllSupports(uint256 tokenId_, uint256 totalAmount_, bool isQuadratic) external view returns(address[] memory, uint256[] memory);
}
