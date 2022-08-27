// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

interface INusicAllocationData {
	enum Participant {
		SPTokenHolders,
		IPOwner,
		Node,
		Tech,
		Community,
		IPIncentive,
		Seller
	}

	enum Phase {
		BeforeFirstTrade,
		OnFirstTrade,
		AfterFirstTrade
	}

	struct Allocation {
		address to;
		uint256 ratio;
	}

	function setAllocationTable(Participant participant_, Phase phase_, address to_, uint256 ratio_) external;
	function getAllocationData(Participant participant_, Phase phase_) external view returns(Allocation memory);
}
