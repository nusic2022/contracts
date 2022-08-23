// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./lib/Token/ERC721.sol";
import "./lib/Token/IERC721Enumerable.sol";
import "./lib/Token/ERC721Burnable.sol";
import "./lib/Token/ERC721Enumerable.sol";
import "./lib/Token/ERC721Pausable.sol";
import "./lib/Ownable.sol";
import "./lib/Counters.sol";

contract NusicNFTCore is
    Ownable,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721Pausable
{
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;
    uint256 private _cap;
    uint256 public royaltyChangeInterval = 7 * 24 * 3600;

    bool public mintOnlyWhitelisted = true;

    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => bool) private _transferable;
    mapping(address => bool) private _mintWhitelist;
    mapping(address => bool) private _operators;
    mapping(uint256 => uint256) private _royalties;
    mapping(uint256 => uint256) private _royalityChangeTimestamp;

    event CapUpdated(uint256 cap);
    event UpdateTokenURI(uint256 indexed tokenId, string tokenURI);
    event UpdateRoyality(uint256 indexed tokenId, uint256 rate);
    event UpdateTransferable(uint256 indexed tokenId, bool status);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialCap_
    ) ERC721(name_, symbol_) {
        require(initialCap_ > 0, "NusicNFTCore: cap is 0");
        _updateCap(initialCap_);
        _tokenIdTracker.increment();
    }

    modifier onlyWhitelisted() {
        require(_mintWhitelist[_msgSender()] || !mintOnlyWhitelisted, "NusicNFTCore: caller must be in the whitelist");
        _;
    }

    modifier onlyOperator() {
        require(_operators[_msgSender()], "NusicNFTCore: caller must be operator");
        _;
    }

    modifier onlyTokenIdExist(uint256 tokenId_) {
        require(_exists(tokenId_), "NusicNFTCore: tokeId not exists");
        _;
    }

    function setWhitelist(address address_, bool status_) public onlyOperator {
        _mintWhitelist[address_] = status_;
    }

    function setOperator(address address_, bool status_) public onlyOwner {
        _operators[address_] = status_;
    }

    function _mint(address to_, uint256 tokenId_) internal virtual override {
        require(ERC721Enumerable.totalSupply() < cap(),"NusicNFTCore: cap exceeded");
        super._mint(to_, tokenId_);
    }

    function _transfer(address from_, address to_, uint256 tokenId_) internal virtual override {
        require(transferable(tokenId_), "NusicNFTCore: Token is not transferable");
        super._transfer(from_, to_, tokenId_);
    }

    function _updateCap(uint256 cap_) private {
        _cap = cap_;
        emit CapUpdated(cap_);
    }

    function _beforeTokenTransfer(
        address from_,
        address to_,
        uint256 tokenId_
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from_, to_, tokenId_);
    }

    function exists(uint256 tokenId_) external view returns (bool) {
        return _exists(tokenId_);
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    function increaseCap(uint256 amount_) public onlyOperator {
        require(amount_ > 0, "NusicNFTCore: amount is 0");

        uint256 newCap = cap() + amount_;
        _updateCap(newCap);
    }

    function mint(address to_) public onlyWhitelisted returns (uint256) {
        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        uint256 _tokenId = _tokenIdTracker.current();
        _mint(to_, _tokenId);
				_transferable[_tokenId] = false;
        _tokenIdTracker.increment();
        return _tokenId;
    }

    function mint(address to_, string calldata tokenURI_, uint256 royality_) public onlyWhitelisted returns (uint256){
				require(royality_ >= 0 && royality_ <= 100, "NusicNFTCore: royality must be 0-100");
        uint256 _tokenId = mint(to_);
        updateTokenURI(_tokenId, tokenURI_);
        updateRoyality(_tokenId, royality_);
        return _tokenId;
    }

    function pause() public virtual onlyOperator {
        _pause();
    }

    function unpause() public virtual onlyOperator {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId_) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId_);
    }

    function tokenURI(uint256 tokenId_) public view virtual override onlyTokenIdExist(tokenId_) returns (string memory) {
        return _tokenURIs[tokenId_];
    }

    function transferable(uint256 tokenId_) public view onlyTokenIdExist(tokenId_) returns (bool) {
        return _transferable[tokenId_];
    }

    function setTransferable(uint256 tokenId_, bool status_) public onlyTokenIdExist(tokenId_) onlyOperator {
        _transferable[tokenId_] = status_;
        emit UpdateTransferable(tokenId_, status_);
    }

    function updateTokenURI(uint256 tokenId_, string calldata uri_) public onlyTokenIdExist(tokenId_) {
        require((
            ownerOf(tokenId_) == _msgSender() && block.timestamp - _royalityChangeTimestamp[tokenId_] >= royaltyChangeInterval)
            || this.isOperator(_msgSender()), 
            "NusicNFTCore: owner of nft can only set once, operators can set always"
            );
        _tokenURIs[tokenId_] = uri_;
        emit UpdateTokenURI(tokenId_, uri_);
    }

    function updateRoyality(uint256 tokenId_, uint256 rate_) public onlyTokenIdExist(tokenId_) {
				require(rate_ >= 0 && rate_ <= 100, "NusicNFTCore: royality must be 0-100");
        require((
            ownerOf(tokenId_) == _msgSender() && block.timestamp - _royalityChangeTimestamp[tokenId_] >= royaltyChangeInterval)
            || this.isOperator(_msgSender()),
            "NusicNFTCore: owner of nft can only set royality after interval from last modification, operators can set always"
            );
        
        _royalties[tokenId_] = rate_;
        _royalityChangeTimestamp[tokenId_] = block.timestamp;
        emit UpdateRoyality(tokenId_, rate_);
    }

    function isOperator(address address_) external view returns(bool) {
        return _operators[address_];
    }

    function royality(uint256 tokenId_) external view onlyTokenIdExist(tokenId_) returns(uint256) {
        return _royalties[tokenId_];
    }

    function royalityChangeTimestamp(uint256 tokenId_) external view onlyTokenIdExist(tokenId_)  returns(uint256) {
        return _royalityChangeTimestamp[tokenId_];
    }

    function isMintWhitelist(address address_) external view returns(bool) {
        return _mintWhitelist[address_];
    }

    function updateRoyaltyChangeInterval(uint256 interval_) external onlyOperator {
        royaltyChangeInterval = interval_;
    }

    function updateMintOnlyWhitelisted(bool status_) external onlyOperator {
        mintOnlyWhitelisted = status_;
    }
}