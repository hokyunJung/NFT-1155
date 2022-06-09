// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./SaleNftToken.sol";

contract Willld is ERC1155 {
    mapping (uint256 => string) private _tokenURIs;   //We create the mapping for TokenID -> URI
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    SaleNftToken public saleNftToken;
    address admin;

    mapping (address => uint256[]) private worksOfOwner; // 주소가 소유한 작품ID
    mapping (address => mapping(uint256 => WorkDetail)) private workDetailsOfOwner; // 주소가 소유한 작품ID의 상세정보
    mapping (uint256 => Work) private workInfos; //작품의 정보들...
    
    struct Work {
        uint256 workId;
        string tokenURI;
        string category;
        string subject;
        address creater;
        uint256 totalAmount;
    }

    struct WorkDetail {
        uint256 workId;
        address owner;
        uint256 currentHaveAmount;
        uint256 currentPrice;
    }

    struct OnSaleInfo {
        uint orderId;
        uint256 workId;
        address seller;
        uint256 saleAmount;
        uint256 salePrice; //개당가격으로 하자...
    }

    constructor() ERC1155("Willd") {
        admin = msg.sender;
    }

    event mintInfo(uint256 workId, address owner, string tokenURI, string category, string subject, uint256 totalAmount);

    //자산 민트..
    function mintNFT(string memory _tokenURI, string memory _category, string memory _subject, uint256 _totalAmount) payable public returns (uint256){
        require(msg.value > 0, "You must send ether for minting.");

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        emit mintInfo(newItemId, msg.sender, _tokenURI, _category, _subject, _totalAmount);

        _mint(msg.sender, newItemId, _totalAmount, "");
        payable(admin).transfer(msg.value);
        _setTokenUri(newItemId, _tokenURI);

        worksOfOwner[msg.sender].push(newItemId);
        workInfos[newItemId] = Work(_tokenURI, _category, _subject, msg.sender, _totalAmount);
        workDetailsOfOwner[msg.sender][newItemId] = WorkDetail(newItemId, msg.sender, _totalAmount, msg.value);
        saleNftToken.setMaxSaleAbleCountOfWorks(msg.sender, newItemId, _totalAmount);

        return newItemId;
    }

    //주소가 가지고 있는 자산들..
    function getWorkOfOwner(address _owner) view public returns (WorkDetail[] memory) {
        uint256[] memory workIds = worksOfOwner[_owner];
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < workIds.length; i++) {
            uint256 balance = balanceOf(_owner, workIds[i]);
            totalBalance += balance;
        }
        require(totalBalance != 0, "Owner did not have work.");

        WorkDetail[] memory workLists = new WorkDetail[](workIds.length);
        for (uint256 i = 0; i < workIds.length; i++) {
            workLists [i] = workDetailsOfOwner[_owner][workIds[i]];
        }

        return workLists;
    }

    //판매 중인 Works 가져오기
    function getSaleOnWorks() view public returns (OnSaleInfo[] memory) {
        uint256[] memory onSaleOrderIds = saleNftToken.getOnSaleOrderIds(); //판매중인 작품 ID들..
        
        OnSaleInfo[] memory saleInfos = new OnSaleInfo[](onSaleOrderIds.length);
        for(uint256 i = 0; i < onSaleOrderIds.length; i++) {
            saleInfos[i] = saleNftToken.getOnSaleInfo(onSaleOrderIds[i]);
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

    function _setTokenUri(uint256 tokenId, string memory tokenURI) private {
        _tokenURIs[tokenId] = tokenURI; 
    }

    function getWorkDetailsOfOwner(address _owner, uint256 _workId) view external returns (WorkDetail memory) {
        return workDetailsOfOwner[_owner][_workId];
    }

    function removeWorkOfOwner(address _owner, uint256 _workId) external {
        for(uint256 i = 0; i < worksOfOwner[_owner].length; i++) {
            if(worksOfOwner[_owner][i] == _workId) {
                worksOfOwner[_owner][i] = 0;
                break;
            }
        }
        for (uint256 i = 0; i < worksOfOwner[_owner].length; i++) {
            if(worksOfOwner[_owner][i] == 0) {
                worksOfOwner[_owner][i] = worksOfOwner[_owner][worksOfOwner[_owner].length - 1];
                worksOfOwner[_owner].pop();
                break;
            }
        }
    }

    function deleteWorkDetailsOfOwner(address _owner, uint256 _workId) external {
        delete workDetailsOfOwner[_owner][_workId];
    }

    function setWorkDetailsOfOwner(address _owner, uint256 _workId, uint256 _currentHaveAmount, uint256 _currentPrice) external {
        workDetailsOfOwner[_owner][_workId] = WorkDetail(_workId, _owner, _currentHaveAmount, _currentPrice);
    }

    function addWorkOfOwner(address _owner, uint256 _workId) external {
        bool isContain = false;
        uint256[] memory works = worksOfOwner[_owner];
        for (uint256 i = 0; i < works.length; i++) {
            if(_workId == works[i]) {
                isContain = true;
                break;
            }
        }
        if (!isContain) {
            worksOfOwner[_owner].push(_workId);
        }
    }

    function addWorkDetailsOfOwner(address _owner, uint256 _workId, uint256 _currentHaveAmount, uint256 _currentPrice) external {
        WorkDetail memory workDetail = workDetailsOfOwner[_owner][_workId];
        if (workDetail.workId != 0) {
            this.setWorkDetailsOfOwner(_owner, _workId, workDetail.currentHaveAmount + _currentHaveAmount, workDetail.currentPrice + _currentPrice);
        } else {
            this.setWorkDetailsOfOwner(_owner, _workId, _currentHaveAmount, _currentPrice);
        }
    }

    function getWorkInfos(uint256 _workId) view public returns (Work memory) {
        return workInfos[_workId];
    }
}
