pragma solidity 0.8.8;
// SPDX-License-Identifier: MIT

import "./lib/Ownable.sol";

contract NusicAllocationData is Ownable {
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

    mapping(Participant => mapping(Phase => Allocation)) allocationTable;

    address public SPTokenHolders = address(0x0);
    address public IPOwner = address(0xC4BFA07776D423711ead76CDfceDbE258e32474A);
    address public Node = address(0xF0Ab3FD4bf892BcB9b40B9c6B5a05e02f3afe833);
    address public Tech = address(0x3FE7995Bf0a505a51196aA11218b181c8497D236);
    address public Community = address(0x0bD170e705ba74d6E260da59AF38EE3980Cf1ce3);
    address public IPIncentive = address(0x3444E23231619b361c8350F4C83F82BCfAB36F65);
    address public Seller = address(0x1);

    constructor() {
        initTable();
    }

    function initTable() internal {
        setAllocationTable(Participant.SPTokenHolders, Phase.BeforeFirstTrade, SPTokenHolders, 6667);
        setAllocationTable(Participant.SPTokenHolders, Phase.OnFirstTrade, SPTokenHolders, 2500);
        setAllocationTable(Participant.SPTokenHolders, Phase.AfterFirstTrade, SPTokenHolders, 500);

        setAllocationTable(Participant.IPOwner, Phase.BeforeFirstTrade, IPOwner, 2067);
        setAllocationTable(Participant.IPOwner, Phase.OnFirstTrade, IPOwner, 5000);
        setAllocationTable(Participant.IPOwner, Phase.AfterFirstTrade, IPOwner, 0);

        setAllocationTable(Participant.Node, Phase.BeforeFirstTrade, Node, 467);
        setAllocationTable(Participant.Node, Phase.OnFirstTrade, Node, 1000);
        setAllocationTable(Participant.Node, Phase.AfterFirstTrade, Node, 0);

        setAllocationTable(Participant.Tech, Phase.BeforeFirstTrade, Tech, 333);
        setAllocationTable(Participant.Tech, Phase.OnFirstTrade, Tech, 700);
        setAllocationTable(Participant.Tech, Phase.AfterFirstTrade, Tech, 0);

        setAllocationTable(Participant.Community, Phase.BeforeFirstTrade, Community, 400);
        setAllocationTable(Participant.Community, Phase.OnFirstTrade, Community, 800);
        setAllocationTable(Participant.Community, Phase.AfterFirstTrade, Community, 0);

        setAllocationTable(Participant.IPIncentive, Phase.BeforeFirstTrade, IPIncentive, 67);
        setAllocationTable(Participant.IPIncentive, Phase.OnFirstTrade, IPIncentive, 0);
        setAllocationTable(Participant.IPIncentive, Phase.AfterFirstTrade, IPIncentive, 0);

        setAllocationTable(Participant.Seller, Phase.BeforeFirstTrade, Seller, 0);
        setAllocationTable(Participant.Seller, Phase.OnFirstTrade, Seller, 0);
        setAllocationTable(Participant.Seller, Phase.AfterFirstTrade, Seller, 9500);
    }

    function setAllocationTable(Participant participant_, Phase phase_, address to_, uint256 ratio_) public onlyOwner {
        allocationTable[participant_][phase_] = Allocation(to_, ratio_);
    }

    function getAllocationData(Participant participant_, Phase phase_) public view returns(Allocation memory) {
        return(allocationTable[participant_][phase_]);
    }
}