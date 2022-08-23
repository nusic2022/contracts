// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

interface INusicNFTCore {
    function royality(uint256 tokenId_) external view returns(uint256);
		function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
