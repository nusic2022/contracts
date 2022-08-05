// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./lib/Ownable.sol";
import "./interfaces/IWhitelist.sol";
import "./lib/Token/IERC20Mintable.sol";

contract Whitelist is Ownable, IWhitelist{
	// USDT address
	IERC20Mintable public fundingToken;
	// NUSIC token
	IERC20Mintable public token;

	uint256 public a = 100;
	uint256 public k = 5;
	uint256 public maxDays = 20;
	uint256 public baseRate = 1000;
	uint256 public rateChangePer = 24 * 3600;
	uint256[] public referalRate = [500, 500]; // 500 is 5%

	struct VestingInfo {
		uint256 timestamp;
		uint256 genesisTimestamp;
		uint256 totalAmount;
		uint256 tgeAmount;
		uint256 cliff;
		uint256 duration;
		uint256 releasedAmount;
		uint256 eraBasis;
		address beneficiary;
		uint256 price;
	}
	VestingInfo[] private _beneficiaries;

	struct CrowdFundingParams {
		uint256 genesisTimestamp;
		uint256 tgeAmountRatio; // 0-10000, if _tgeAmountRatio is 50, the ratio is 50 / 10**2 = 50%
		uint256 cliff;
		uint256 duration;
		uint256 eraBasis;          // seconds
		uint256 startTimestamp; // funding start
		uint256 endTimestamp;   // funding end
		uint256 highest;        // investment max, this limitation is ETH/BNB amount, not token amount
		uint256 lowest;         // investment min, this limitation is ETH/BNB amount, not token amount
	}
	CrowdFundingParams private _crowdFundingParams;

	uint256 private _totalAmount;
	mapping(address => uint256) private _beneficiaryIndex;
	mapping(address => address) private referals;

	event BeneficiaryAdded(address indexed beneficiary, uint256 amount);
	event BeneficiaryActivated(uint256 index, address indexed beneficiary);
	event BeneficiaryRevoked(uint256 index, address indexed beneficiary, uint256 amount);

	event TokensReleased(address indexed beneficiary, uint256 amount);
	event Withdraw(address indexed receiver, uint256 amount);

	event CrowdFundingAdded(address account, uint256 price, uint256 amount);
	event AddReferer(address user, address referer);

	constructor(address token_, address fundingToken_) {
		token = IERC20Mintable(token_);
		fundingToken = IERC20Mintable(fundingToken_);
	}

	function getBeneficiary(uint256 index_) external view returns (VestingInfo memory) {
		return _beneficiaries[index_];
	}

	function getIndex(address beneficiary_) external view returns(bool, uint256) {
		return (_beneficiaryIndex[beneficiary_] > 0, _beneficiaryIndex[beneficiary_]);
	}

	function getBeneficiaryCount() external view returns (uint256) {
		return _beneficiaries.length;
	}

	function getAllBeneficiaries() external view onlyOwner returns (VestingInfo[] memory) {
		return _beneficiaries;
	}

	function setCrowdFundingParams(
		uint256 genesisTimestamp_,
		uint256 tgeAmountRatio_,
		uint256 cliff_,
		uint256 duration_,
		uint256 eraBasis_,
		uint256 startTimestamp_,
		uint256 endTimestamp_,
		uint256 highest_,
		uint256 lowest_
	) external onlyOwner {
		require(tgeAmountRatio_ >= 0 && tgeAmountRatio_ <= 10000, "Whitelist: tge ratio is more than 10000");
		require(eraBasis_ <= duration_, "Whitelist: eraBasis_ smaller than duration_");
		require(endTimestamp_ > startTimestamp_, "Whitelist: end time is later than start");

		_crowdFundingParams.genesisTimestamp = genesisTimestamp_;
		_crowdFundingParams.tgeAmountRatio = tgeAmountRatio_;
		_crowdFundingParams.cliff = cliff_;
		_crowdFundingParams.duration = duration_;
		_crowdFundingParams.eraBasis = eraBasis_;
		_crowdFundingParams.startTimestamp = startTimestamp_;
		_crowdFundingParams.endTimestamp = endTimestamp_;
		_crowdFundingParams.highest = highest_;
		_crowdFundingParams.lowest = lowest_;
	}

	function crowdFundingParams() external view returns(CrowdFundingParams memory) {
		return _crowdFundingParams;
	}

	function crowdFunding(uint256 amount_, address referer_) external {
		require(_crowdFundingParams.highest >= amount_, 'Whitelist: more than highest');
		require(_crowdFundingParams.lowest <= amount_, 'Whitelist: less than lowest');

		require(_crowdFundingParams.startTimestamp <= block.timestamp,
				'Whitelist: crowd funding is not start');
		require(_crowdFundingParams.endTimestamp >= block.timestamp,
				'Whitelist: crowd funding is end');

		(bool has_, ) = this.getIndex(_msgSender());
		require(!has_, 'Whitelist: This address is in the beneficiary list');

		uint256 allowance = fundingToken.allowance(_msgSender(), address(this));
		require(allowance >= amount_, "Whitelist: Please approve tokens before transferring");
		uint256 fundingTokenBalance = fundingToken.balanceOf(_msgSender());
		require(fundingTokenBalance >= amount_, "Whitelist: Balance is not enough");

		(, uint256 rate_, uint256 reward_) = this.getCurrentRate(amount_);
		require(reward_ > 0, 'Whitelist: tokens must be greater than 0');

		// add beneficiary
		VestingInfo memory info;

		info.timestamp = block.timestamp;
		info.beneficiary = _msgSender();
		info.genesisTimestamp =	_crowdFundingParams.genesisTimestamp;
		info.totalAmount = reward_;
		info.tgeAmount = reward_ * _crowdFundingParams.tgeAmountRatio / 10000;
		info.releasedAmount = 0;
		info.cliff = _crowdFundingParams.cliff;
		info.duration =	_crowdFundingParams.duration;
		info.eraBasis =	_crowdFundingParams.eraBasis;
		info.price = rate_;

		_addBeneficiary(info);

		fundingToken.transferFrom(_msgSender(), address(this), amount_);

		if(referer_ != address(0)) addReferer(referer_);

		// Get referers and send usdt
		(address referer1, address referer2) = this.getLayer2Referers(_msgSender());
		if(referer1 != address(0) && referalRate[0] > 0) {
			fundingToken.transfer(referer1, amount_ * referalRate[0] / 10000);
		}
		if(referer2 != address(0) && referalRate[1] > 0) {
			fundingToken.transfer(referer2, amount_ * referalRate[1] / 10000);
		}

		emit CrowdFundingAdded(_msgSender(), rate_, reward_);
	}

  function getUserTokenBalance() external view returns(uint256){
			return(fundingToken.balanceOf(_msgSender()));
	}

  function getAllowance() external view returns(uint256){
			return fundingToken.allowance(_msgSender(), address(this));
	}

	function total() external view returns (uint256) {
		uint256 totalAmount_ = 0;
		for (uint256 i = 0; i < _beneficiaries.length; i++) {
			totalAmount_ = totalAmount_ + _beneficiaries[i].totalAmount;
		}
		return totalAmount_;
	}

	function releasableAll() external view returns (uint256) {
		uint256 _releasable = 0;
		for (uint256 i = 0; i < _beneficiaries.length; i++) {
			VestingInfo memory info = _beneficiaries[i];
			_releasable = _releasable + _releasableAmount(
				info.genesisTimestamp,
				info.totalAmount,
				info.tgeAmount,
				info.cliff,
				info.duration,
				info.releasedAmount,
				info.eraBasis
			);
		}
		return _releasable;
	}

	function releasable(uint256 index_) external view returns (uint256) {
		VestingInfo memory info = _beneficiaries[index_];
		uint256 _releasable = _releasableAmount(
			info.genesisTimestamp,
			info.totalAmount,
			info.tgeAmount,
			info.cliff,
			info.duration,
			info.releasedAmount,
			info.eraBasis
		);
		return _releasable;
	}

	function released() external view returns (uint256) {
		return _getReleasedAmount();
	}

	function releaseAll() external onlyOwner {
		uint256 _releasable = this.releasableAll();
		require(_releasable > 0, "Whitelist: no tokens are due!");

		for (uint256 i = 0; i < _beneficiaries.length; i++) {
			_release(_beneficiaries[i]);
		}
	}

	function release() external {
		(bool has_, uint256 index_) = this.getIndex(_msgSender());
		require(has_, "Whitelist: user not found in beneficiary list");
		require(index_ >= 0 && index_ < _beneficiaries.length, "Whitelist: index out of range!");

		VestingInfo storage info = _beneficiaries[index_];
		require(_msgSender() == info.beneficiary, "Whitelist: unauthorised sender!");
		_release(info);
	}

	function withdraw(address to_, uint256 amount_) external onlyOwner {
		require(to_ != address(0), "Whitelist: withdraw address is the zero address");
		require(amount_ > uint256(0), "Whitelist: withdraw amount is zero");
		require(fundingToken.balanceOf(address(this)) >= amount_, "Whitelist: withdraw amount must smaller than balance");
		fundingToken.transfer(to_, amount_);
	}

	function updateToken(address token_) external onlyOwner {
		require(token_ != address(0), "Whitelist: token_ is the zero address!");
		token = IERC20Mintable(token_);
	}

	function updateTotalAmount(uint256 amount_) external onlyOwner {
		_totalAmount = amount_;
	}

	function totalAmount() external view returns (uint256) {
		return _totalAmount;
	}

	function getCurrentRate(uint256 amount_) external view returns(uint256 _days, uint256 _rate, uint256 _tokens) {
		_days = (block.timestamp - _crowdFundingParams.startTimestamp) / rateChangePer;
		_days = _days > maxDays ? maxDays : _days;
		// amount_ = 100U, _rate will increated by days
		_rate = k * _days + a;
		_tokens = amount_ / _rate * baseRate;
	}

	function updateRateParams(
		uint256 a_,
		uint256 k_,
		uint256 maxDays_,
		uint256 baseRate_,
		uint256 rateChangePer_
	) external onlyOwner {
		a = a_;
		k = k_;
		maxDays = maxDays_;
		baseRate = baseRate_;
		rateChangePer = rateChangePer_;
	}

	function updateReferalParams(uint256[] memory referalRate_) external onlyOwner {
		require(referalRate_.length == 2, "Whitelist: the level of referals should be two");
		referalRate = referalRate_;
	}

	function addReferer(address referer_) public {
		require(referals[_msgSender()] == address(0), "Whtelist: you have bound referer already");
		referals[_msgSender()] = referer_;
		emit AddReferer(_msgSender(), referer_);
	}

	function getReferer(address user_) external view returns(address) {
		return referals[user_];
	}

	function getLayer2Referers(address user_) external view returns(address, address) {
		return(referals[user_], referals[referals[user_]]);
	}


	/**
		* =================================================================
		* Private methods
		* =================================================================
		*/
	function _addBeneficiary(VestingInfo memory info_) internal {
		require(
			info_.genesisTimestamp >= info_.timestamp,
			"Whitelist: genesis too soon!"
		);
		require(
			info_.beneficiary != address(0),
			"Whitelist: beneficiary_ is the zero address!"
		);
		require(
			info_.genesisTimestamp + info_.cliff + info_.duration <= type(uint256).max,
			"Whitelist: out of uint256 range!"
		);
		require(
			info_.eraBasis > 0,
			"Whitelist: eraBasis_ must be greater than 0!"
		);

		(bool has_, ) = this.getIndex(info_.beneficiary);
		require(!has_, "Whitelist: beneficiary exist");

		VestingInfo storage info = _beneficiaries.push();
		info.timestamp = info_.timestamp;
		info.beneficiary = info_.beneficiary;
		info.genesisTimestamp = info_.genesisTimestamp;
		info.totalAmount = info_.totalAmount;
		info.tgeAmount = info_.tgeAmount;
		info.releasedAmount = info_.releasedAmount;
		info.cliff = info_.cliff;
		info.duration = info_.duration;
		info.eraBasis = info_.eraBasis;
		info.price = info_.price;

		_totalAmount = _totalAmount + info_.totalAmount;
		_beneficiaryIndex[info_.beneficiary] = _beneficiaries.length - 1;
		emit BeneficiaryAdded(info_.beneficiary, info_.totalAmount);
	}

	function _release(VestingInfo storage info) private {
		uint256 unreleased = _releasableAmount(
			info.genesisTimestamp,
			info.totalAmount,
			info.tgeAmount,
			info.cliff,
			info.duration,
			info.releasedAmount,
			info.eraBasis
		);

		if (unreleased > 0) {
			info.releasedAmount = info.releasedAmount + unreleased;
			token.mint(info.beneficiary, unreleased);
			emit TokensReleased(info.beneficiary, unreleased);
		}
	}

	function _getReleasedAmount() private view returns (uint256) {
		uint256 releasedAmount = 0;
		for (uint256 i = 0; i < _beneficiaries.length; i++) {
			releasedAmount = releasedAmount + _beneficiaries[i].releasedAmount;
		}
		return releasedAmount;
	}

	function _releasableAmount(
		uint256 genesisTimestamp_,
		uint256 totalAmount_,
		uint256 tgeAmount_,
		uint256 cliff_,
		uint256 duration_,
		uint256 releasedAmount_,
		uint256 eraBasis_
	) private view returns (uint256) {
		return _vestedAmount(genesisTimestamp_, totalAmount_, tgeAmount_, cliff_, duration_, eraBasis_) - releasedAmount_;
	}

	function _vestedAmount(
		uint256 genesisTimestamp_,
		uint256 totalAmount_,
		uint256 tgeAmount_,
		uint256 cliff_,
		uint256 duration_,
		uint256 eraBasis_
	) private view returns (uint256) {
		if(totalAmount_ < tgeAmount_) return 0;
		if(block.timestamp < genesisTimestamp_) return 0;
		uint256 timeLeftAfterStart = block.timestamp - genesisTimestamp_;

		if (timeLeftAfterStart < cliff_) return tgeAmount_;
		uint256 linearVestingAmount = totalAmount_ - tgeAmount_;
		if (timeLeftAfterStart >= cliff_ + duration_) return linearVestingAmount + tgeAmount_;

		uint256 releaseMilestones = (timeLeftAfterStart - cliff_) / eraBasis_ + 1;
		uint256 totalReleaseMilestones = (duration_ + eraBasis_ - 1) / eraBasis_ + 1;
		return (linearVestingAmount / totalReleaseMilestones) * releaseMilestones + tgeAmount_;
	}
}
