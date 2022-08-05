// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./Token/IWETH.sol";

contract BuyLink {
    IWETH private immutable _wrappedBnb;
    IERC20 private immutable _link;
    IERC20 private immutable _pegLink;
    address private immutable _pancakeRouter;
    address private immutable _pegSwapRouter;

    bytes4 private constant WBNB_DEPOSIT_SELECTOR =
        bytes4(keccak256(bytes("deposit()")));
    bytes4 private constant SWAP_SELECTOR =
        bytes4(
            keccak256(
                bytes(
                    "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)"
                )
            )
        );
    bytes4 private constant PEG_SWAP_SELECTOR =
        bytes4(keccak256(bytes("swap(uint256,address,address)")));

    constructor(
        address wrappedBnb_,
        address pegLink_,
        address link_,
        address pancakeRouter_,
        address pegSwapRouter_
    ) {
        require(
            wrappedBnb_ != address(0),
            "BuyLink: wrappedBnb_ is zero address"
        );
        require(pegLink_ != address(0), "BuyLink: pegLink_ is zero address");
        require(link_ != address(0), "BuyLink: link_ is zero address");
        require(
            pancakeRouter_ != address(0),
            "BuyLink: pancakeRouter_ is zero address"
        );
        require(
            pegSwapRouter_ != address(0),
            "BuyLink: pegSwapRouter_ is zero address"
        );

        _wrappedBnb = IWETH(wrappedBnb_);
        _pegLink = IERC20(pegLink_);
        _link = IERC20(link_);
        _pancakeRouter = pancakeRouter_;
        _pegSwapRouter = pegSwapRouter_;
    }

    function _approve(address token_, address to_) private {
        if (IERC20(token_).allowance(address(this), to_) == 0) {
            IERC20(token_).approve(to_, ~uint256(0));
        }
    }

    function _swap(
        address router_,
        address fromCurrency_,
        address toCurrency_,
        uint256 amount_,
        address to_
    ) private returns (bool success) {
        address[] memory path = new address[](2);
        path[0] = fromCurrency_;
        path[1] = toCurrency_;

        _approve(fromCurrency_, router_);

        (success, ) = router_.call(
            (
                abi.encodeWithSelector(
                    SWAP_SELECTOR,
                    amount_,
                    0,
                    path,
                    to_,
                    block.timestamp
                )
            )
        );
    }

    function _pegSwap(
        address router_,
        address fromCurrency_,
        address toCurrency_,
        uint256 amount_
    ) private returns (bool success) {
        _approve(fromCurrency_, router_);

        (success, ) = router_.call(
            (
                abi.encodeWithSelector(
                    PEG_SWAP_SELECTOR,
                    amount_,
                    fromCurrency_,
                    toCurrency_
                )
            )
        );
    }

    function _bnbToWrappedBnb() private returns (bool success) {
        uint256 amount = address(this).balance;
        (success, ) = address(_wrappedBnb).call{value: amount}(
            (abi.encodeWithSelector(WBNB_DEPOSIT_SELECTOR))
        );
    }

    function _wrappedBnbToPegLink() private returns (bool) {
        return
            _swap(
                address(_pancakeRouter),
                address(_wrappedBnb),
                address(_pegLink),
                _wrappedBnb.balanceOf(address(this)),
                address(this)
            );
    }

    function _pegLinkToLink() private returns (bool) {
        return
            _pegSwap(
                address(_pegSwapRouter),
                address(_pegLink),
                address(_link),
                _pegLink.balanceOf(address(this))
            );
    }

    function _buyLink() internal {
        bool _success = _bnbToWrappedBnb();
        require(_success, "BuyLink: swap BNB to WBNB fail");

        _success = _wrappedBnbToPegLink();
        require(_success, "BuyLink: swap WBNB to PLINK fail");

        _success = _pegLinkToLink();
        require(_success, "BuyLink: swap PLINK to LINK fail");
    }
}