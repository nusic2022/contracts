// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./lib/Context.sol";
import "./lib/Token/IERC165.sol";
// import "./lib/Token/IERC721.sol";
import "./lib/Token/IERC20.sol";
import "./lib/Address.sol";
import "./lib/Token/SafeERC20.sol";
import "./lib/EnumerableSet.sol";
import "./interfaces/IAccessControl.sol";
import "./lib/Strings.sol";
import "./lib/Token/ERC165.sol";
import "./lib/AccessControl.sol";
import "./lib/AccessControlEnumerable.sol";
import "./lib/Counters.sol";
import "./interfaces/INusicNFTCore.sol";
import "./interfaces/ISupportProofTokenFactory.sol";
import "./interfaces/INusicAllocationData.sol";

contract NFTMarketplace is AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
		INusicAllocationData public _allocation;

    struct Order {
        address seller;
        address buyer;
        uint256 tokenId;
        address paymentToken;
        uint256 price;
        uint256 timestamp;
    }

    EnumerableSet.AddressSet private _supportedPaymentTokens;
		ISupportProofTokenFactory public _supportProofTokenFactory;
    INusicNFTCore public nftCore;
		mapping(uint256 => uint256) public _tradingTimes; // key: tokenId, value: times
    uint256 public feeDecimal;
    uint256 public feeRate;
    address public feeRecipient;
		bool public isQuadratic = true;
    Counters.Counter private _orderIdTracker;

    mapping(uint256 => Order) public orders;
    EnumerableSet.UintSet private _onSaleOrders;
    mapping(address => EnumerableSet.UintSet) private _onSaleOrdersOfOwner;
    bool public isPause = false;

    event OrderAdded(
        uint256 indexed orderId,
        address indexed seller,
        uint256 indexed tokenId,
        address paymentToken,
        uint256 price,
        uint256 timestamp
    );
    event PriceUpdated(uint256 indexed orderId, uint256 price);
    event OrderCancelled(uint256 indexed orderId);
    event OrderMatched(
        uint256 indexed orderId,
        address indexed seller,
        address indexed buyer,
        uint256 tokenId,
        address paymentToken,
        uint256 price,
        uint256 timestamp
    );
    event feeRateUpdated(uint256 feeDecimal, uint256 feeRate);

    constructor(
        address nftAddress_,
        address paymentToken_,
				address supportProofTokenFactory_,
				address allocationContract_,
        uint256 feeDecimal_,
        uint256 feeRate_,
        address feeRecipient_
    ) {
        require(
            nftAddress_ != address(0),
            "NFTMarketplace: nftAddress_ is zero address"
        );
        require(
            feeRecipient_ != address(0),
            "NFTMarketplace: feeRecipient_ is zero address"
        );

        nftCore = INusicNFTCore(nftAddress_);
        _updateFeeRate(feeDecimal_, feeRate_);
        feeRecipient = feeRecipient_;
        _orderIdTracker.increment();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MAINTAINER_ROLE, _msgSender());

        _supportedPaymentTokens.add(paymentToken_);
				_supportProofTokenFactory = ISupportProofTokenFactory(supportProofTokenFactory_);
				_allocation = INusicAllocationData(allocationContract_);
    }

    modifier onlySupportedPaymentToken(address paymentToken_) {
        require(
            isPaymentTokenSupported(paymentToken_),
            "NFTMarketplace: unsupport payment token"
        );
        _;
    }

    modifier onlyOnSaleOrder(uint256 orderId_) {
        require(
            _onSaleOrders.contains(orderId_),
            "NFTMarketplace: order is not on sale"
        );
        _;
    }

    modifier onlyOnSaleOrderOfOwner(uint256 orderId_, address owner_) {
        require(
            _onSaleOrdersOfOwner[owner_].contains(orderId_),
            "NFTMarketplace: order is not on sale"
        );
        _;
    }

    modifier canMatch(
        uint256 orderId_,
        address buyer_,
        uint256 price_
    ) {
        require(
            !isSeller(orderId_, buyer_),
            "NFTMarketplace: buyer must be different from seller"
        );
        require(
            price_ == orders[orderId_].price,
            "NFTMarketplace: price has been changed"
        );
        _;
    }

    function _calculateFee(uint256 orderId_) private view returns (uint256) {
        Order storage _order = orders[orderId_];
        if (feeRate == 0) {
            return 0;
        }

        return (feeRate * _order.price) / 10**(feeDecimal + 2);
    }

    function _updateFeeRate(uint256 feeDecimal_, uint256 feeRate_) internal {
        require(
            feeRate_ < 10**(feeDecimal_ + 2),
            "NFTMarketplace: bad fee rate"
        );
        feeDecimal = feeDecimal_;
        feeRate = feeRate_;
        emit feeRateUpdated(feeDecimal_, feeRate_);
    }

    function isSeller(uint256 orderId_, address seller_)
        public
        view
        returns (bool)
    {
        return orders[orderId_].seller == seller_;
    }

    function supportedPaymentTokens() public view returns (address[] memory) {
        return _supportedPaymentTokens.values();
    }

    function onSaleOrderCount() public view returns (uint256) {
        return _onSaleOrders.length();
    }

    function onSaleOrderAt(uint256 index_) public view returns (uint256) {
        return _onSaleOrders.at(index_);
    }

    function onSaleOrdersByTokenId(uint256 tokenId_) public view returns (uint256 orderId_) {
        for(uint256 i = 0; i < _onSaleOrders.length(); i++) {
            uint256 _orderId = uint256(_onSaleOrders.at(i));
            Order memory _order = orders[_orderId];
            if(_order.tokenId == tokenId_) {
                orderId_ = _orderId;
                break;
            }
        }
    }

    function onSaleOrders() public view returns (uint256[] memory) {
        return _onSaleOrders.values();
    }

    function onSaleOrderLimit(uint256 from_, uint256 length_) public view returns (uint256[] memory) {
        uint256[] memory orders_ = new uint256[](length_);
        for(uint256 i = from_; i < from_ + length_; i++) orders_[i - from_] = uint256(_onSaleOrders.at(i));
        return orders_;
    }

    function onSaleOrderOfOwnerCount(address owner_)
        public
        view
        returns (uint256)
    {
        return _onSaleOrdersOfOwner[owner_].length();
    }

    function onSaleOrderOfOwnerAt(address owner_, uint256 index_)
        public
        view
        returns (uint256)
    {
        return _onSaleOrdersOfOwner[owner_].at(index_);
    }

    function onSaleOrdersOfOwner(address owner_)
        public
        view
        returns (uint256[] memory)
    {
        return _onSaleOrdersOfOwner[owner_].values();
    }

    function onSaleOrdersOfOwnerByTokenId(address owner_, uint256 tokenId_) public view returns (uint256 orderId_) {
        for(uint256 i = 0; i < _onSaleOrdersOfOwner[owner_].length(); i++) {
            uint256 _orderId = uint256(_onSaleOrdersOfOwner[owner_].at(i));
            Order memory _order = orders[_orderId];
            if(_order.tokenId == tokenId_) {
                orderId_ = _orderId;
                break;
            }
        }
    }

    function onSaleOrdersOfOwnerLimit(address owner_, uint256 from_, uint256 length_) public view returns (uint256[] memory) {
        uint256[] memory orders_ = new uint256[](length_);
        for(uint256 i = from_; i < from_ + length_; i++) orders_[i - from_] = uint256(_onSaleOrdersOfOwner[owner_].at(i));
        return orders_;
    }

    function nextOrderId() public view returns (uint256) {
        return _orderIdTracker.current();
    }

    function updateNftCore(address _nftCoreAddress) external onlyRole(MAINTAINER_ROLE){
        nftCore = INusicNFTCore(_nftCoreAddress);
    }

    function updateFeeRecipient(address feeRecipient_) external onlyRole(MAINTAINER_ROLE){
        // If feeRecipient is zero, burn the fee
        feeRecipient = feeRecipient_;
    }

    function updateFeeRate(uint256 feeDecimal_, uint256 feeRate_) external onlyRole(MAINTAINER_ROLE) {
        _updateFeeRate(feeDecimal_, feeRate_);
    }

    function addPaymentToken(address paymentToken_) external onlyRole(MAINTAINER_ROLE) {
        require(paymentToken_ != address(0), "NFTMarketplace: payment token is zero address");
        require(_supportedPaymentTokens.add(paymentToken_), "NFTMarketplace: already supported");
    }

    function isPaymentTokenSupported(address paymentToken_) public view returns (bool){
        return _supportedPaymentTokens.contains(paymentToken_);
    }

    function addOrder(
        uint256 tokenId_,
        address paymentToken_,
        uint256 price_
    ) public onlySupportedPaymentToken(paymentToken_)
    {
        require(!isPause, "NFTMarketplace: addOrder is paused");
        require(
            nftCore.ownerOf(tokenId_) == _msgSender(),
            "NFTMarketplace: sender is not owner of token"
        );
        require(
            nftCore.getApproved(tokenId_) == address(this) || nftCore.isApprovedForAll(_msgSender(), address(this)),
            "NFTMarketplace: The contract is unauthorized to manage this token"
        );
        require(
            price_ > 0,
            "NFTMarketplace: price must be greater than 0"
        );

        uint256 _orderId = _orderIdTracker.current();
        Order storage _order = orders[_orderId];
        _order.seller = _msgSender();
        _order.tokenId = tokenId_;
        _order.paymentToken = paymentToken_;
        _order.price = price_;
        _order.timestamp = block.timestamp;
        _orderIdTracker.increment();

        _onSaleOrders.add(_orderId);
        _onSaleOrdersOfOwner[_msgSender()].add(_orderId);

        nftCore.transferFrom(_msgSender(), address(this), tokenId_);

        emit OrderAdded(
            _orderId,
            _msgSender(),
            tokenId_,
            paymentToken_,
            price_,
            block.timestamp
        );
    }

    function updatePrice(uint256 orderId_, uint256 price_)
        public
        onlyOnSaleOrderOfOwner(orderId_, _msgSender())
    {
        require(
            price_ > 0,
            "NFTMarketplace: price must be greater than 0"
        );
        Order storage _order = orders[orderId_];
        _order.price = price_;

        emit PriceUpdated(orderId_, price_);
    }

    function cancelOrder(uint256 orderId_)
        external
        onlyOnSaleOrderOfOwner(orderId_, _msgSender())
    {
        Order storage _order = orders[orderId_];
        _onSaleOrders.remove(orderId_);
        _onSaleOrdersOfOwner[_msgSender()].remove(orderId_);

        nftCore.transferFrom(address(this), _msgSender(), _order.tokenId);
        emit OrderCancelled(orderId_);
    }

    function cancelAllOrders() external onlyRole(MAINTAINER_ROLE) {
        for(uint256 i = 0; i < _onSaleOrders.length(); i++) {
            uint256 orderId_ = uint256(_onSaleOrders.at(i));
            Order storage _order = orders[orderId_];
            _onSaleOrders.remove(orderId_);
            _onSaleOrdersOfOwner[_msgSender()].remove(orderId_);

            nftCore.transferFrom(address(this), _order.seller, _order.tokenId);
            emit OrderCancelled(orderId_);
        }
    }

    function pause(bool pause_) external onlyRole(MAINTAINER_ROLE) {
        isPause = pause_;
    }

    function matchOrder(uint256 orderId_, uint256 price_)
        external
        payable
        onlyOnSaleOrder(orderId_)
        canMatch(orderId_, _msgSender(), price_)
    {
        Order storage _order = orders[orderId_];
        _order.buyer = _msgSender();
        _onSaleOrders.remove(orderId_);
        _onSaleOrdersOfOwner[_order.seller].remove(orderId_);

				uint256 royality = nftCore.royality(_order.tokenId);
				
				// Charge fee
        uint256 _feeAmount = _calculateFee(orderId_);
        if (_feeAmount > 0) {
            IERC20(_order.paymentToken).safeTransferFrom(
                _msgSender(),
                feeRecipient,
                _feeAmount
            );
        }
				// Send to seller
        IERC20(_order.paymentToken).safeTransferFrom(
            _msgSender(),
            _order.seller,
            (_order.price - _feeAmount) * (100 - royality) / 100
        );

				// Send commissions to supporters
				// ###### 根据不同阶段，把佣金发给多组用户
				// 参考 _tradingTimes
				uint256 _totalSharedAmount = (_order.price - _feeAmount) * royality / 100;
				(address[] memory _supporters, uint256[] memory _amounts) = this.getAllSupports(orderId_, _totalSharedAmount);
				for(uint256 i = 0; i < _supporters.length; i++) {
					if(_amounts[i] > 0) {
						IERC20(_order.paymentToken).safeTransferFrom(
							_msgSender(),
							_supporters[i],
							_amounts[i]
						);
					}
				}

				// Send NFT to buyer
        nftCore.transferFrom(address(this), _msgSender(), _order.tokenId);

        emit OrderMatched(
            orderId_,
            _order.seller,
            _order.buyer,
            _order.tokenId,
            _order.paymentToken,
            _order.price,
            block.timestamp
        );
    }
		struct SupportData {
				address supporter;
				uint256 balance;
		}
		function getAllSupports(uint256 orderId_, uint256 totalAmount_) external view returns(address[] memory _supporters, uint256[] memory _amounts){
			Order memory _order = orders[orderId_];
			uint256 _tokenId = _order.tokenId;
			(_supporters, _amounts) = _supportProofTokenFactory.getAllSupports(_tokenId, totalAmount_, true);
		}

		function updateSupportProofTokenFactory(address address_) external onlyRole(MAINTAINER_ROLE) {
			_supportProofTokenFactory = ISupportProofTokenFactory(address_);
		}

		function updateIsQuadratic(bool isQuadratic_) external onlyRole(MAINTAINER_ROLE) {
			isQuadratic = isQuadratic_;
		}

	function updateAllocationContract(address allocationContract_) public onlyRole(MAINTAINER_ROLE) {
		_allocation = INusicAllocationData(allocationContract_);
	}
}