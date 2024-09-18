// # Task2-使用 Solidity 實現一個 NFT Swap
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTSwap is IERC721Receiver {
    // 掛單
    event List(
        address indexed seller,
        address indexed nftAddr,
        uint256 indexed tokenId,
        uint256 price
    );

    // 購買
    event Purchase(
        address indexed buyer,
        address indexed nftAddr,
        uint256 indexed tokenId,
        uint256 price
    );

    // 撤單
    event Revoke(
        address indexed seller,
        address indexed nftAddr,
        uint256 indexed tokenId
    );

    // 更新
    event Update(
        address indexed seller,
        address indexed nftAddr,
        uint256 indexed tokenId,
        uint256 newPrice
    );

    // Order結構
    struct Order {
        address owner;
        uint256 price;
    }
    // NFT Order Mapping
    mapping(address => mapping(uint256 => Order)) public nftList;

    fallback() external payable {}

    // 掛單(地址, NFT ID)
    function list(address _nftAddr, uint256 _tokenId, uint256 _price) public {
        IERC721 _nft = IERC721(_nftAddr); // 用IERC721
        require(_nft.getApproved(_tokenId) == address(this), "Need Approval"); // 限制:合約需要獲得授權
        require(_price > 0); // 限制:價格要求大約0

        Order storage _order = nftList[_nftAddr][_tokenId]; 
        _order.owner = msg.sender; //NFT 擁有人
        _order.price = _price; // NFT 價格
        // NFT轉移到合約
        _nft.safeTransferFrom(msg.sender, address(this), _tokenId);

        emit List(msg.sender, _nftAddr, _tokenId, _price);
    }

    // 購買(地址, NFT ID)
    function purchase(address _nftAddr, uint256 _tokenId) public payable {
        Order storage _order = nftList[_nftAddr][_tokenId]; 
        require(_order.price > 0, "Invalid Price"); // 限制:價格要求大約0
        require(msg.value >= _order.price, "Increase price"); // 限制:價格必須大於或等於
        
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order"); // 限制:地址必須是合約本身

        // NFT轉移到買方
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        
        payable(_order.owner).transfer(_order.price);
        payable(msg.sender).transfer(msg.value - _order.price);

        delete nftList[_nftAddr][_tokenId]; // 删除order

        emit Purchase(msg.sender, _nftAddr, _tokenId, _order.price);
    }

    // 撤單
    function revoke(address _nftAddr, uint256 _tokenId) public {
        Order storage _order = nftList[_nftAddr][_tokenId]; 
        require(_order.owner == msg.sender, "Not Owner"); // 限制:由擁有人撤單

        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order"); // 限制:地址必須是合約本身

        // NFT轉移到擁有人
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        delete nftList[_nftAddr][_tokenId]; 

        emit Revoke(msg.sender, _nftAddr, _tokenId);
    }

    // 更新NFT價格
    function update(
        address _nftAddr,
        uint256 _tokenId,
        uint256 _newPrice
    ) public {
        require(_newPrice > 0, "Invalid Price"); // 限制:價格要求大約0
        Order storage _order = nftList[_nftAddr][_tokenId]; 
        require(_order.owner == msg.sender, "Not Owner"); // 限制:由擁有人更新

        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order"); // 限制:地址必須是合約本身

        _order.price = _newPrice;

        emit Update(msg.sender, _nftAddr, _tokenId, _newPrice);
    }

    function onERC721Received(
        address operator,
        address from,
        uint tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}