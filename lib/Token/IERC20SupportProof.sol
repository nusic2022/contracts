// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "./IERC20.sol";

interface IERC20SupportProof is IERC20 {
    function mint(address to, uint256 amount) external;
		function initialize(address erc20, address nft, uint256 tokenId) external returns(bool);
}
