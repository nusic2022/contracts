// SPDX-License-Identifier: MIT

/**
 * This contract will make an agreement to add/remove liquidity to the pancake.finance
 * marketplace at some time by ChainLink keeper.
 * The owner who can operate the add/remove liquidity is only owner.
 * You can set this owner as gnosis-safe multisign address, and both parts will confirm
 * together to active this agreement, and do the action at the agreed time.
 */
pragma solidity 0.8.8;

import "./lib/SafeMath.sol";
import "./lib/Ownable.sol";
import "./lib/Token/IERC20.sol";
import "./lib/Address.sol";
import './interfaces/IPancakeRouter.sol';

contract LiquidityAgreement is Ownable {
	address public tokenA;
	address public tokenB;
    uint    public amountADesired;
    uint    public amountBDesired;
    uint256 public activeAddTimestamp = 2524579200;
    uint256 public activeRemoveTimestamp = 2524579200;
    address public lpTokenAddress;

	// PancakeRouter on BSC mainnet
	// IPancakeRouter02 public pancakeRouter = IPancakeRouter02(address(0x10ED43C718714eb63d5aA57B78B54704E256024E));

	// PancakeRouter on BSC testnet
    address pancakeRouterAddress = address(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
	IPancakeRouter02 public pancakeRouter = IPancakeRouter02(pancakeRouterAddress);

    function getLPTokenBalance() external view returns(uint256) {
        return IERC20(lpTokenAddress).balanceOf(address(this));
    }
	
	function setLiquidityParams(
        address tokenA_, 
        address tokenB_,
        address lpTokenAddress_,
        uint    amountADesired_,
        uint    amountBDesired_,
        uint256 activeAddTimestamp_,
        uint256 activeRemoveTimestamp_
    ) public onlyOwner {
        require(activeAddTimestamp_ >= block.timestamp, "Add time is too near");
        require(activeRemoveTimestamp_ >= block.timestamp, "Remove time is too near");
        activeAddTimestamp = activeAddTimestamp_;
        activeRemoveTimestamp = activeRemoveTimestamp_;
		tokenA = tokenA_;
		tokenB = tokenB_;
        lpTokenAddress = lpTokenAddress_;
        amountADesired = amountADesired_;
        amountBDesired = amountBDesired_;
	}

    function addLiquidity() external {
        require(block.timestamp >= activeAddTimestamp, "Activation is not available");
        require(IERC20(tokenA).balanceOf(address(this)) >= amountADesired, "TokenA balance not enough");
        require(IERC20(tokenB).balanceOf(address(this)) >= amountBDesired, "TokenB balance not enough");

        IERC20(tokenA).approve(pancakeRouterAddress, amountADesired);
        IERC20(tokenB).approve(pancakeRouterAddress, amountBDesired);

		pancakeRouter.addLiquidity(
			tokenA,
			tokenB,
			amountADesired,
			amountBDesired,
			amountADesired,
			amountBDesired,
			address(this),
			block.timestamp + 10 * 60
		);
    }

    function removeLiquidity(uint liquidity_) external onlyOwner {
        require(block.timestamp >= activeRemoveTimestamp, "Activation is not available");
        require(this.getLPTokenBalance() >= liquidity_, "LP tokens are not enough");

        IERC20(lpTokenAddress).approve(pancakeRouterAddress, liquidity_);

		pancakeRouter.removeLiquidity(
            tokenB,
            tokenA,
            liquidity_,
            100,
            100,
            address(this),
            block.timestamp + 10 * 60
		);
    }

    // Withdraw Tokens from contract to address of both
    function withdraw(address toA_, uint256 amountA_, address toB_, uint256 amountB_) external onlyOwner {
        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));
        require(balanceA >= amountA_, "Balance of tokenA is not enough");
        require(balanceB >= amountB_, "Balance of tokenB is not enough");
        IERC20(tokenA).transfer(toA_, amountA_);
        IERC20(tokenB).transfer(toB_, amountB_);
    }

    // Withdraw LP token from contract to address
    function withdrawLPToken(address to_, uint256 amount_) external onlyOwner {
        uint256 balance = IERC20(lpTokenAddress).balanceOf(address(this));
        require(balance >= amount_, "LP token balance is not enough");
        IERC20(lpTokenAddress).transfer(to_, amount_);
    }
}