// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "./IERC20.sol";

interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
		function burn(address to, uint256 amount) external;
    function decimals() external returns (uint256);
}
