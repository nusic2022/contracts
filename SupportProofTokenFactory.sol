// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

import "./lib/Ownable.sol";
import "./lib/Token/IERC20Mintable.sol";
import "./lib/Token/IERC20SupportProof.sol";
import "./lib/Token/IERC721.sol";
import "./SupportProofToken.sol";

contract SupportProofTokenFactory is Ownable {
	IERC20Mintable public erc20; // Supported Token
	IERC721 public nft; // NFT address

	mapping(uint256 => address) public SPTokens;
	uint256 public rate = 1000; // 1000 means 100 erc20 token will mint 1 spToken

	event SPTContractCreated(address spToken_, IERC20Mintable erc20_, IERC721 nft_, uint256 tokenId_);

	constructor(address erc20_, address nft_) {
		erc20 = IERC20Mintable(erc20_);
		nft = IERC721(address(nft_));
	}

	function createSPToken(uint256 tokenId_) public returns(address _spToken) {
		require(IERC721(nft).ownerOf(tokenId_) != address(0x0), "TokenId not exist");
		bytes memory bytecode = type(SupportProofToken).creationCode;
		bytes32 salt = keccak256(abi.encodePacked(nft, tokenId_));
		assembly {
				_spToken := create2(0, add(bytecode, 32), mload(bytecode), salt)
		}
		IERC20SupportProof(_spToken).initialize(address(erc20), address(nft), tokenId_);
		SPTokens[tokenId_] = _spToken;
		emit SPTContractCreated(_spToken, erc20, nft, tokenId_);
	}

	function support(uint256 amount_, uint256 tokenId_) public {
		// Be sure the allowance of spending supported tokens from this contract is enough
		require(IERC20Mintable(erc20).allowance(msg.sender, address(this)) >= amount_, "Allowance is not enough");
		// Check balance of supported tokens
		require(IERC20Mintable(erc20).balanceOf(msg.sender) >= amount_, "Balance is not enough");
		address _spToken = SPTokens[tokenId_];
		// If the SP Token contract has not deployed, create it.
		if(_spToken == address(0x0)) _spToken = createSPToken(tokenId_);
		// Mint SP tokens for the user
		IERC20Mintable(_spToken).mint(msg.sender, amount_ * rate / 1e5);
		// Transfer supported tokens from user's account to this contract
		IERC20Mintable(erc20).transferFrom(msg.sender, address(this), amount_);
	}

	function unsupport(uint256 amount_, uint256 tokenId_) public {
		address _spToken = SPTokens[tokenId_];
		// Be sure the sp token contract is exist.
		require(_spToken != address(0x0), "SPToken of this tokenId is not exist");
		// Be sure the allowance of spending Support Proof tokens from this contract is enough
		require(IERC20Mintable(_spToken).allowance(msg.sender, address(this)) >= amount_, "Allowance of SPToken is not enough");
		// Check balance of SP Tokens
		require(IERC20Mintable(_spToken).balanceOf(msg.sender) >= amount_, "Balance of SPToken is not enough");
		// Send SP Tokens to address(0x0) and destroy them
		IERC20Mintable(_spToken).burn(msg.sender, amount_);
		// Return tokens back to supporter
		IERC20Mintable(erc20).transfer(msg.sender, amount_ / rate * 1e5);
	}

	function getSPTokenBalance(uint256 tokenId_) public view returns(uint256) {
		return IERC20Mintable(SPTokens[tokenId_]).balanceOf(msg.sender);
	}

	function getSPTokenBalanceOfUser(uint256 tokenId_, address user_) public view returns (uint256) {
		return IERC20Mintable(SPTokens[tokenId_]).balanceOf(user_);
	}

	function getSPTokenTotalSupply(uint256 tokenId_) public view returns(uint256) {
		return IERC20Mintable(SPTokens[tokenId_]).totalSupply();
	}

	function getSPTokenName(uint256 tokenId_) public view returns(string memory) {
		return IERC20Mintable(SPTokens[tokenId_]).name();
	}

	function getSPTokenSymbol(uint256 tokenId_) public view returns(string memory) {
		return IERC20Mintable(SPTokens[tokenId_]).symbol();
	}

	function getSPTokenAddress(uint256 tokenId_) public view returns(address) {
		return SPTokens[tokenId_];
	}

	function updateNFT(address nftAddress_) public onlyOwner {
		nft = IERC721(nftAddress_);
	}

	function updateERC20(address address_) public onlyOwner {
		erc20 = IERC20Mintable(address_);
	}

	function updateRate(uint256 rate_) public onlyOwner {
		rate = rate_;
	}
}