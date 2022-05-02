// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./SaleNftToken.sol";

contract Xcube is ERC1155 {
    mapping (uint256 => string) private _tokenURIs;   //We create the mapping for TokenID -> URI
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    SaleNftToken public saleNftToken;
    address admin;

    mapping (address => uint256[]) private worksOfOwner; // 주소가 소유한 작품 리스트
    mapping (address => mapping(uint256 => WorkInfo) private workInfosOfOwner; // 주소가 소유한 작품 상세 리스트
    mapping (uint256 => Work) private works; //작품의 정보들
    
    struct Work {
        string category;
        string subject;
        address creater;
        uint256 totalAmount;
    }

    struct WorkInfo {
        uint256 workId;
        address owner;
        uint256 currentHaveAmount;
        uint256 currentPrice;
    }

    struct SaleInfo {
        address seller;
        uint256 numberOfSales;
        uint256 salePrice;
        //Work work;
    }

    constructor() ERC1155("Willd") {
        admin = msg.sender;
    }

    event mintInfo(address owner, string tokenURI, string category, string subject, uint256 totalAmount);

    //자산 민트..
    function mintNFT(string memory tokenURI, string memory _category, string memory _subject, uint256 _totalAmount) payable public returns (uint256){
        require(msg.value > 0, "You must send ether for minting.");

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        emit mintInfo(msg.sender, tokenURI, _category, _subject, _totalAmount);

        _mint(msg.sender, newItemId, _totalAmount, "");
        payable(admin).transfer(msg.value);
        _setTokenUri(newItemId, tokenURI);

        assetsOfOwner[msg.sender].push(newItemId);
        workInfos[newItemId] = Work(newItemId, _category, _subject, msg.sender, _totalAmount, _totalAmount, msg.value);

        return newItemId;
    }

    function _setTokenUri(uint256 tokenId, string memory tokenURI) private {
        _tokenURIs[tokenId] = tokenURI; 
    }


    //주소가 가지고 있는 자산들..
    function getWorkOfOwner(address _owner) view public returns (Work[] memory) {
        uint256[] memory works = assetsOfOwner[_owner];
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < works.length; i++) {
            uint256 balance = balanceOf(_owner, works[i]);
            totalBalance += balance;
        }
        require(totalBalance != 0, "Owner did not have work.");

        Work[] memory workLists = new Work[](works.length);
        for(uint256 i = 0; i < works.length; i++) {
            workLists[i] = workInfos[i];
        }
        return workLists;
    }

    //판매 중인 Works 가져오기
    function getSaleOnWorks() view public returns (SaleInfo[] memory) {
        uint256[] memory onSaleWorks = saleNftToken.getOnSaleWorkArray(); //판매중인 작품 ID들..
        uint256 totalSaleInfos = 0;
        for (uint256 i = 0; i < onSaleWorks.length; i++) {
            totalSaleInfos += saleNftToken.getOnSaleWorkInfoSize(onSaleWorks[i]);
        }
        
        SaleInfo[] memory saleInfos = new SaleInfo[](totalSaleInfos);
        for(uint256 i = 0; i < totalSaleInfos; i++) {
            SaleInfo[] memory infos = saleNftToken.getOnSaleWorkInfo(onSaleWorks[i]);
            for (uint256 j = 0; j < infos.length; j++) {
               saleInfos[i] = infos[j];
            }
        }
        return saleInfos;
    }
    
    //xcube와 saleNftToken을 이어준다.
    function setSaleNftToken(address _saleNftToken) public {
        require(admin == msg.sender, "You not admin.");
        saleNftToken = SaleNftToken(_saleNftToken);
    }
    //실행 가능한 권한 설정 : setApprovalForAll -> 지갑선택 -> operator : SALENFTTOKEN AT 주소, approved : true
    //실행 가능한 권한 보기 : isApprovalForAll -> setApprovalForAll -> 해당 지갑이 true/false 인지...
    //판매 등록 : setForSaleNftToken -> 지갑선택 -> _nftTokenId : key, _price : 1
/*
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
*/
}
