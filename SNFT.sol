// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./lib/Token/ERC721Enumerable.sol";
import "./lib/Ownable.sol";
import "./lib/Counters.sol";

contract SNFT is Ownable, ERC721Enumerable {
		using Counters for Counters.Counter;
		Counters.Counter private _tokenIdTracker;
		uint256 private _cap;
		string public defaultTokenURI; // IPFS uri for metadata including NFT name, description, image, attributes etc.

		mapping(address => bool) private _mintWhitelist;
		mapping(address => bool) private _operators;
    mapping(uint256 => string) private _tokenURIs;

		event CapUpdated(uint256 cap);
    event UpdateTokenURI(uint256 indexed tokenId, string tokenURI);

		constructor(
				string memory name_,
				string memory symbol_,
				uint256 initialCap_
		) ERC721(name_, symbol_) {
				require(initialCap_ > 0, "MysteryBoxNFt: cap is 0");
				_updateCap(initialCap_);
				_tokenIdTracker.increment();
		}

    modifier onlyWhitelisted() {
        require(_mintWhitelist[_msgSender()], "MysteryBoxNFt: caller must be in the whitelist");
        _;
    }

		modifier onlyOperator() {
			require(_operators[_msgSender()], "MysteryBoxNFt: caller must be operator");
			_;
		}

		modifier onlyTokenIdExist(uint256 tokenId_) {
			require(_exists(tokenId_), "NusicNFTCore: tokeId not exists");
			_;
		}

		function _updateCap(uint256 cap_) private {
				_cap = cap_;
				emit CapUpdated(cap_);
		}

    function mint(address to_) public onlyWhitelisted returns (uint256) {
				// Whitelist is MysteryBoxManager contract address
        uint256 _tokenId = _tokenIdTracker.current();
        _mint(to_, _tokenId);
				_tokenURIs[_tokenId] = defaultTokenURI;
        _tokenIdTracker.increment();
        emit UpdateTokenURI(_tokenId, defaultTokenURI);
        return _tokenId;
    }

		function setWhitelist(address address_, bool status_) public onlyOperator {
			_mintWhitelist[address_] = status_;
		}

		function setOperator(address address_, bool status_) public onlyOwner {
			_operators[address_] = status_;
		}

    function _mint(address to_, uint256 tokenId_) internal virtual override {
        require(ERC721Enumerable.totalSupply() < cap(),"MysteryBoxNFt: cap exceeded");
        super._mint(to_, tokenId_);
    }

		    function exists(uint256 tokenId_) external view returns (bool) {
        return _exists(tokenId_);
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    function increaseCap(uint256 amount_) public onlyOperator {
        require(amount_ > 0, "MysteryBoxNFt: amount is 0");

        uint256 newCap = cap() + amount_;
        _updateCap(newCap);
    }

		function isOperator(address address_) external view returns(bool) {
			return _operators[address_];
		}

    function updateTokenURI(uint256 tokenId_, string calldata uri_) public onlyTokenIdExist(tokenId_) onlyWhitelisted {
        _tokenURIs[tokenId_] = uri_;
        emit UpdateTokenURI(tokenId_, uri_);
    }

		function tokenURI(uint256 tokenId_) public view virtual override onlyTokenIdExist(tokenId_) returns (string memory) {
        return _tokenURIs[tokenId_];
    }

		function updateDefaultTokenURI(string calldata uri_) public onlyOperator {
			defaultTokenURI = uri_;
		}

}
