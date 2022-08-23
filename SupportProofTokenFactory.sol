// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

import "./lib/Ownable.sol";
import "./lib/Token/IERC20Mintable.sol";
import "./lib/Token/IERC20SupportProof.sol";
import "./lib/Token/IERC721.sol";
import "./SupportProofToken.sol";
import "./lib/Strings.sol";

contract SupportProofTokenFactory is Ownable {
    using Strings for uint256;

	IERC20Mintable public erc20; // CPT
	IERC721 public nft; // CPN

	mapping(uint256 => address) public SPTokens;
    mapping(uint256 => address[]) public supporters;
	uint256 public rate = 1000; // 1000 means 100 erc20 token will mint 1 spToken

	event SPTContractCreated(address spToken_, IERC20Mintable erc20_, IERC721 nft_, uint256 tokenId_);
    event Support(address spToken_, uint256 tokenId_, address supporter_, uint256 amount_);
    event Unsupport(address spToken_, uint256 tokenId_, address supporter_, uint256 amount_);

	constructor(address erc20_, address nft_) {
		erc20 = IERC20Mintable(erc20_);
		nft = IERC721(address(nft_));
	}

	function createSPToken(uint256 tokenId_) public returns(address _spToken) {
        require(IERC721(nft).ownerOf(tokenId_) != address(0x0), "TokenId not exist");
		require(SPTokens[tokenId_] == address(0x0), "SPToken is created");
		bytes memory bytecode = type(SupportProofToken).creationCode;
		string memory _name = string(abi.encodePacked("Support Proof Token #", tokenId_.toString()));
		string memory _symbol = string(abi.encodePacked("SPT#", tokenId_.toString()));
		bytecode = abi.encodePacked(bytecode, abi.encode(_name, _symbol));
		bytes32 salt = keccak256(abi.encodePacked(nft, tokenId_));
		assembly {
            _spToken := create2(0, add(bytecode, 32), mload(bytecode), salt)
            if iszero(extcodesize(_spToken)) {
            	revert(0, 0)
            }
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
        // Add support to array, the supporter in this array will not be deleted, will check the balanceOf sptoken
        addSupport(tokenId_, msg.sender);
        emit Support(_spToken, tokenId_, msg.sender, amount_);
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
        emit Unsupport(_spToken, tokenId_, msg.sender, amount_);
	}

    function addSupport(uint256 tokenId_, address supporter_) internal {
        address[] storage _supporters = supporters[tokenId_];
        _supporters.push(supporter_);
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

	function getAllSupports(uint256 tokenId_, uint256 totalAmount_, bool isQuadratic) public view returns(
		address[] memory _supporters,
		uint256[] memory _amounts)
	{
		_supporters = supporters[tokenId_];
		_amounts = new uint256[](_supporters.length);
		uint256 totalSupply = getSPTokenTotalSupply(tokenId_);
		if(!isQuadratic) {
			for(uint256 i; i < _supporters.length; i++) {
				_amounts[i] = getSPTokenBalanceOfUser(tokenId_, _supporters[i]) * totalAmount_ / totalSupply ;
			}
		} else {
			uint256 _total = 0;
			for(uint256 i; i < _supporters.length; i++) {
				_total = _total + sqrt(getSPTokenBalanceOfUser(tokenId_, _supporters[i]));
			}
			for(uint256 i; i < _supporters.length; i++) {
				_amounts[i] = sqrt(getSPTokenBalanceOfUser(tokenId_, _supporters[i])) * totalAmount_ / _total ;
			}
		}
	}
	
	function sqrt(uint x) public pure returns (uint y) {
		uint z = (x + 1) / 2;
		y = x;
		while (z < y) {
			y = z;
			z = (x / z + z) / 2;
		}
	}
}