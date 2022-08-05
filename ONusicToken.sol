// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

import "./lib/SafeMath.sol";
import "./lib/Ownable.sol";
import "./lib/Token/ERC20.sol";
import "./lib/Address.sol";
import "./interfaces/ITokenController.sol";
import "./lib/AccessControlEnumerable.sol";

/// ONusic Token
contract ONusicToken is
	ERC20("Nusic Token", "ONusic"),
	Ownable,
	AccessControlEnumerable
{
	using Address for address;
	using SafeMath for uint256;

	uint256 public cap = 3e26;
	bool public transferAllowed = false;

	bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
	bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

	constructor() {
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
		_setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
		_setupRole(MINTER_ROLE, _msgSender());
		_setupRole(BURNER_ROLE, _msgSender());
	}

	/// @notice Creates `_amount` token to `_to`. Must only be called by the owner
	function mint(address _to, uint256 _amount) public {
		require(
			hasRole(MINTER_ROLE, _msgSender()),
			"Token: must have minter role to mint"
		);
		require(
			cap >= totalSupply() + _amount,
			"Token: touch cap"
		);
		_mint(_to, _amount);
	}

	/// @notice Burn `_amount` token from `_from`. Must only be called by the owner
	function burn(address _from, uint256 _amount) public {
		require(
			hasRole(BURNER_ROLE, _msgSender()),
			"Token: must have burner role to burn"
		);
		_burn(_from, _amount);
	}

	/// @notice Override ERC20.transfer
	function transfer(address recipient, uint256 amount) public override returns (bool) {
		require(transferAllowed, "Token: transfer not allowed");
		super.transfer(recipient, amount);
		return true;
	}

	/// @notice Override ERC20.transferFrom
	function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
		require(transferAllowed, "Token: transferFrom not allowed");
		super.transferFrom(sender, recipient, amount);
		return true;
	}

	function setTransferAllowed(bool _status) external onlyOwner {
		transferAllowed = _status;
	}
}