// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./SaleNftToken.sol";

contract XcubeTest is ERC1155 {
    mapping (uint256 => string) private _tokenURIs;   //We create the mapping for TokenID -> URI
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping (address => uint256[]) private worksOfOwner; // 주소가 소유한 작품ID
    mapping (address => mapping(uint256 => WorkDetail)) private workDetailsOfOwner; // 주소가 소유한 작품ID의 상세정보
    mapping (uint256 => Work) private workInfos; //작품의 정보들...
    
    uint256[] private onSaleOrderIds; //판매 중인 orderIds
    mapping(uint256 => bool) private isContainsOrderId; //onSaleOrderIds에 orderId가 있는가?
    mapping(uint256 => OnSaleInfo) private onSaleInfos; //판매 중인 작품의 판매 정보
    mapping(address => mapping(uint256 => OnSaleInfo)) private onSaleInfosOfAddress;// 주소가 팔고 있는 리스트
    mapping(address => mapping(uint256 => uint256)) private maxSaleAbleCountOfWorks;// 주소가 가진 작품의 최대 판매 가능 수



    struct Work {
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
    }

    //function mintTest(string memory _tokenURI, address _seller, string memory _category, string memory _subject, uint256 _totalAmount, uint256 _msgValue) public returns (uint256) {
    function mintTest() public returns (uint256) {
        string memory _tokenURI = "test";
        address _seller = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        string memory _category = "A";
        string memory _subject = "A";
        uint256 _totalAmount = 10;
        uint256 _msgValue = 100;

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        _mint(_seller, newItemId, _totalAmount, "");
        //payable(admin).transfer(msg.value);
        _setTokenUri(newItemId, _tokenURI);

        worksOfOwner[_seller].push(newItemId);
        workInfos[newItemId] = Work(_category, _subject, _seller, _totalAmount);
        workDetailsOfOwner[_seller][newItemId] = WorkDetail(newItemId, _seller, _totalAmount, _msgValue);
        setMaxSaleAbleCountOfWorks(msg.sender, newItemId, _totalAmount);

        return newItemId;
    }

    //주소가 가지고 있는 자산들..
    function getWorkOfOwnerTest(address _owner) view public returns (WorkDetail[] memory) {
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

    event SaleWork(uint256 orderId);

    //NFT 를 팔기 위해 사용
    function setForSaleWorkTest(uint256 _workId, uint256 _saleAmount, uint256 _salePrice) public returns(uint256) {
        uint256 maxSaleAmount = getMaxSaleAbleCountOfWorks(msg.sender, _workId); //소유자가 해당 작품으로 팔수 있는 갯수
        require(maxSaleAmount >= _saleAmount, "You don't sell Works becuase you have not enough balance.1");
        uint256 saleAbleAmount = maxSaleAmount - _saleAmount; //판매가능한 양
        require(saleAbleAmount >= 0, "You don't sell Works becuase you have not enough balance.2");

        setMaxSaleAbleCountOfWorks(msg.sender, _workId, saleAbleAmount); //쵀대 판매 가능 수 수정
        uint orderId = uint(keccak256(abi.encode(block.timestamp, msg.sender, _salePrice))) % 100000000000;
        addOnSaleOrderIds(orderId); //판매중 리스트에 orderId 넣기
        onSaleInfos[orderId] = OnSaleInfo(orderId, _workId, msg.sender, _saleAmount, _salePrice); //판매 중 리스트 상세정보 넣기
        onSaleInfosOfAddress[msg.sender][orderId] = OnSaleInfo(orderId, _workId, msg.sender, _saleAmount, _salePrice); //주소가 팔고 있는 리스트에 넣기

        emit SaleWork(orderId);
        return orderId;
    }

    //NFT 판매 취소
    function setCancelForSale(uint256 _orderId) public {
        require(getIsContainsOrderId(_orderId), string(abi.encodePacked("This orderId not exist : ", Strings.toString(_orderId))));
        OnSaleInfo memory saleInfo = onSaleInfos[_orderId];

        require(saleInfo.seller == msg.sender, "You are not NFT token owner.");
        require(isApprovedForAll(msg.sender, address(this)), "NFT token owner did not approve SaleNftToken.");

        removeOnSaleOrderIds(_orderId); //판매 중인 orderIds에서 제거    
        delete onSaleInfos[_orderId]; //판매 상세 목록에서 제거
        delete onSaleInfosOfAddress[saleInfo.seller][_orderId]; //해당주소가 팔고 있는 정보 삭제
        setMaxSaleAbleCountOfWorks(saleInfo.seller, saleInfo.workId, saleInfo.saleAmount); //최대 판매 가능 개수 수정
    }

    //판매 중인 NFT 가져오기
    function getSaleOnWorksTest() view public returns (OnSaleInfo[] memory) {
        uint256[] memory onSaleOrderIds = getOnSaleOrderIds(); //판매중인 작품 ID들..
        
        OnSaleInfo[] memory saleInfos = new OnSaleInfo[](onSaleOrderIds.length);
        for(uint256 i = 0; i < onSaleOrderIds.length; i++) {
            saleInfos[i] = getOnSaleWorkInfo(onSaleOrderIds[i]);
        }
        return saleInfos;
    }


    event purchase(address seller, address buyer, uint256 orderId, uint256 workId, uint256 saleAmount, uint256 buyAmout, uint256 salePrice, uint256 buyPrice);

    //NFT 를 사기 위해 사용
    function purchaseWorkTest(address buyer, uint256 _orderId, uint256 _amount, uint256 _value) public {
        require(getIsContainsOrderId(_orderId), string(abi.encodePacked("This orderId not exist : ", Strings.toString(_orderId))));
        require(_amount > 0, "amount must is high than zero");
        OnSaleInfo memory saleInfo = onSaleInfos[_orderId];
        require(saleInfo.seller != buyer, "You are this NFT token owner.");
        require(saleInfo.saleAmount != 0, "This saleAmout is invalid value");
        require(saleInfo.saleAmount >= _amount, "your buyAmout over saleAmount");
        require(_value >= _amount * saleInfo.salePrice, "your pay not enough");
        
        
        if (saleInfo.saleAmount != _amount) {
            //갯수를 다르게 산다면...
            onSaleInfos[_orderId] = OnSaleInfo(saleInfo.orderId, saleInfo.workId, saleInfo.seller, saleInfo.saleAmount - _amount, saleInfo.salePrice);
            onSaleInfosOfAddress[saleInfo.seller][saleInfo.orderId] = OnSaleInfo(saleInfo.orderId, saleInfo.workId, saleInfo.seller, saleInfo.saleAmount - _amount, saleInfo.salePrice);
            
        } else {
            //같다면.. 다 산거니까..
            
            removeOnSaleOrderIds(_orderId); //판매 중인 orderIds에서 제거    
            delete onSaleInfos[_orderId]; //판매 상세 목록에서 제거
            delete onSaleInfosOfAddress[saleInfo.seller][_orderId]; //해당주소가 팔고 있는 정보 삭제
        }
        
        //event purchase(address seller, address buyer, uint256 orderId, uint256 workId, uint256 saleAmount, uint256 buyAmout, uint256 salePrice, uint256 buyPrice);
        emit purchase(saleInfo.seller, buyer, _orderId, saleInfo.workId, saleInfo.saleAmount, _amount, saleInfo.salePrice, _value);

        //payable(saleInfo.seller).transfer(msg.value);
        safeTransferFrom(saleInfo.seller, buyer, saleInfo.workId, _amount, "");
        
    }

    function getIsContainsOrderId(uint256 _orderId) view private returns (bool) {
        return isContainsOrderId[_orderId];
    }

    function removeOnSaleOrderIds(uint256 _orderId) private {
        delete isContainsOrderId[_orderId];
        for(uint256 i = 0; i < onSaleOrderIds.length; i++) {
            if(onSaleOrderIds[i] == _orderId) {
                onSaleOrderIds[i] = 0;
            }
        }
        for(uint256 i = 0; i < onSaleOrderIds.length; i++) {
            if(onSaleOrderIds[i] == 0) {
                onSaleOrderIds[i] = onSaleOrderIds[onSaleOrderIds.length - 1];
                onSaleOrderIds.pop();
            }
        }
    }

    //판매중인 작품 리스트
    function getOnSaleOrderIds() view public returns (uint256[] memory) {
        return onSaleOrderIds;
    }

    //판매중인 작품 상세 정보
    function getOnSaleWorkInfo(uint256 _orderId) view public returns (OnSaleInfo memory) {
        return onSaleInfos[_orderId];
    }

    function addOnSaleOrderIds(uint256 _orderId) private {
        isContainsOrderId[_orderId] = true;
        onSaleOrderIds.push(_orderId);
    }

    function getMaxSaleAbleCountOfWorks(address owner, uint256 _workId) view public returns (uint256) {
        uint256 res = maxSaleAbleCountOfWorks[owner][_workId];
        return res;
    }

    function setMaxSaleAbleCountOfWorks(address owner, uint256 _workId, uint256 _amount) public {
        maxSaleAbleCountOfWorks[owner][_workId] = _amount;
    }

    function _setTokenUri(uint256 _tokenId, string memory _tokenURI) private {
        _tokenURIs[_tokenId] = _tokenURI; 
    }

}