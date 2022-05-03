// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Xcube.sol";

contract SaleNftToken {
    Xcube public xcube;

    constructor (address _xcubeTokenAddress) {
        xcube = Xcube(_xcubeTokenAddress);
    }

    uint256[] private onSaleOrderIds; //판매 중인 orderIds
    mapping(uint256 => Xcube.OnSaleInfo) private onSaleInfos; //판매 중인 작품의 판매 정보
    mapping(address => mapping(uint256 => Xcube.OnSaleInfo)) private onSaleInfosOfAddress;// 주소가 팔고 있는 리스트
    mapping(address => mapping(uint256 => uint256)) private maxSaleCountOfWorks;// 주소가 가진 작품의 최대 판매 가능 수

    event purchase(address seller, address buyer, uint256 orderId, uint256 workId, uint256 saleAmount, uint256 buyAmout, uint256 salePrice, uint256 buyPrice);
    event ableSellAmout(uint256 saleAbleAmount);

    function getMaxSaleCountOfWorks(uint256 _workId) view public returns (uint256) {
        uint256 res = maxSaleCountOfWorks[msg.sender][_workId]; //이게 왜자꾸 0이지...??
        return res;
    }

    function setMaxSaleCountOfWorks(uint256 _workId, uint256 totalAmount) public {
        maxSaleCountOfWorks[msg.sender][_workId] = totalAmount;
    }

    //work 를 팔기 위해 사용
    function setForSaleWork(uint256 _workId, uint256 _saleAmount, uint256 _salePrice) public {
        require(xcube.isApprovedForAll(msg.sender, address(this)), "NFT token owner did not approve SaleNftToken.");
        require(_saleAmount > 0, "numberOfSale is must hight than zero.");
        require(_salePrice > 0, "salePrice is is must hight than zero.");


        uint256 maxSaleAmount = maxSaleCountOfWorks[msg.sender][_workId]; //소유자가 해당 작품으로 팔수 있는 갯수
        emit ableSellAmout(maxSaleAmount);
        //uint256 saleAbleAmount = maxSaleAmount - _saleAmount; //판매가능한 양
        //emit ableSellAmout(saleAbleAmount);

        //require(saleAbleAmount > 1, "You don't sell Works becuase you have not enough balance.");
/*
        emit ableSellAmout(saleAbleAmount);

        maxSaleCountOfWorks[msg.sender][_workId] = saleAbleAmount; //쵀대 판매 가능 수 수정
        uint orderId = uint(keccak256(abi.encode(block.timestamp, msg.sender, _salePrice)));
        addOnSaleOrderIds(orderId); //판매중 리스트에 orderId 넣기
        onSaleInfos[orderId] = Xcube.OnSaleInfo(orderId, _workId, msg.sender, _saleAmount, _salePrice); //판매 중 리스트 상세정보 넣기
        onSaleInfosOfAddress[msg.sender][orderId] = Xcube.OnSaleInfo(orderId, _workId, msg.sender, _saleAmount, _salePrice); //주소가 팔고 있는 리스트에 넣기
*/
    }

    function addOnSaleOrderIds(uint256 _orderId) private {
        onSaleOrderIds.push(_orderId);
    }

    //판매중인 작품 리스트
    function getOnSaleOrderIds() view public returns (uint256[] memory) {
        return onSaleOrderIds;
    }

    //판매중인 작품 상세 정보
    function getOnSaleWorkInfo(uint256 _orderId) view public returns (Xcube.OnSaleInfo memory) {
        return onSaleInfos[_orderId];
    }

    function removeOnSaleOrderIds(uint256 _orderId) private {
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

    //NFT 를 사기 위해 사용
    function purchaseWork(uint256 _orderId, uint256 _amout) public payable {
        require(_amout > 0, "amount must is high than zero");
        Xcube.OnSaleInfo memory saleInfo = onSaleInfos[_orderId];
        require(saleInfo.seller != msg.sender, "You are this NFT token owner.");
        require(saleInfo.saleAmount != 0, "This saleAmout is invalid value");

        removeOnSaleOrderIds(_orderId); //판매 중인 orderIds에서 제거
        delete onSaleInfos[_orderId]; //판매 상세 목록에서 제거
        delete onSaleInfosOfAddress[saleInfo.seller][_orderId]; //해당주소가 팔고 있는 정보 삭제
        
        //event purchase(address seller, address buyer, uint256 orderId, uint256 workId, uint256 saleAmount, uint256 buyAmout, uint256 salePrice, uint256 buyPrice);
        emit purchase(saleInfo.seller, msg.sender, _orderId, saleInfo.workId, saleInfo.saleAmount, _amout, saleInfo.salePrice, msg.value);

        payable(saleInfo.seller).transfer(msg.value);
        xcube.safeTransferFrom(saleInfo.seller, msg.sender, saleInfo.workId, _amout, "");
        maxSaleCountOfWorks[saleInfo.seller][saleInfo.workId] = xcube.balanceOf(saleInfo.seller, saleInfo.workId);
    }
    
}
