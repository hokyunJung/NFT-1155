// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./Xcube.sol";

contract SaleNftToken {
    Xcube public xcube;

    constructor (address _xcubeTokenAddress) {
        xcube = Xcube(_xcubeTokenAddress);
    }

    uint256[] private onSaleOrderIds; //판매 중인 orderIds
    mapping(uint256 => bool) private isContainsOrderId; //onSaleOrderIds에 orderId가 있는가?
    mapping(uint256 => Xcube.OnSaleInfo) private onSaleInfos; //판매 중인 작품의 판매 정보
    mapping(address => mapping(uint256 => Xcube.OnSaleInfo)) private onSaleInfosOfAddress;// 주소가 팔고 있는 리스트
    mapping(address => mapping(uint256 => uint256)) private maxSaleAbleCountOfWorks;// 주소가 가진 작품의 최대 판매 가능 수

    event SaleWork(uint256 orderId);

    //NFT 를 팔기 위해 사용
    function setForSaleWork(uint256 _workId, uint256 _saleAmount, uint256 _salePrice) public returns(uint256) {
        uint256 maxSaleAmount = getMaxSaleAbleCountOfWorks(msg.sender, _workId); //소유자가 해당 작품으로 팔수 있는 갯수
        require(maxSaleAmount >= _saleAmount, "You don't sell Works becuase you have not enough balance.1");
        uint256 saleAbleAmount = maxSaleAmount - _saleAmount; //판매가능한 양
        require(saleAbleAmount >= 0, "You don't sell Works becuase you have not enough balance.2");

        this.setMaxSaleAbleCountOfWorks(msg.sender, _workId, saleAbleAmount); //쵀대 판매 가능 수 수정
        uint orderId = uint(keccak256(abi.encode(block.timestamp, msg.sender, maxSaleAmount))) % 100000000000;
        addOnSaleOrderIds(orderId); //판매중 리스트에 orderId 넣기
        onSaleInfos[orderId] = Xcube.OnSaleInfo(orderId, _workId, msg.sender, _saleAmount, _salePrice); //판매 중 리스트 상세정보 넣기
        onSaleInfosOfAddress[msg.sender][orderId] = Xcube.OnSaleInfo(orderId, _workId, msg.sender, _saleAmount, _salePrice); //주소가 팔고 있는 리스트에 넣기

        emit SaleWork(orderId);
        return orderId;
    }

    //NFT 판매 취소
    function setCancelForSale(uint256 _orderId) public {
        require(getIsContainsOrderId(_orderId), string(abi.encodePacked("This orderId not exist : ", Strings.toString(_orderId))));
        Xcube.OnSaleInfo memory saleInfo = onSaleInfos[_orderId];

        require(saleInfo.seller == msg.sender, "You are not NFT token owner.");
        require(xcube.isApprovedForAll(msg.sender, address(this)), "NFT token owner did not approve SaleNftToken.");

        removeOnSaleOrderIds(_orderId); //판매 중인 orderIds에서 제거    
        delete onSaleInfos[_orderId]; //판매 상세 목록에서 제거
        delete onSaleInfosOfAddress[saleInfo.seller][_orderId]; //해당주소가 팔고 있는 정보 삭제
        this.setMaxSaleAbleCountOfWorks(saleInfo.seller, saleInfo.workId, saleInfo.saleAmount); //최대 판매 가능 개수 수정
    }


    event purchase(address seller, address buyer, uint256 orderId, uint256 workId, uint256 saleAmount, uint256 buyAmout, uint256 salePrice, uint256 buyPrice);
    //NFT 를 사기 위해 사용
    function purchaseWork(uint256 _orderId, uint256 _amount) public payable {
        require(getIsContainsOrderId(_orderId), string(abi.encodePacked("This orderId not exist : ", Strings.toString(_orderId))));
        require(_amount > 0, "amount must is high than zero");
        Xcube.OnSaleInfo memory saleInfo = onSaleInfos[_orderId];
        require(saleInfo.seller != msg.sender, "You are this NFT token owner.");
        require(saleInfo.saleAmount != 0, "This saleAmout is invalid value");
        require(saleInfo.saleAmount >= _amount, "your buyAmout over saleAmount");
        require(msg.value >= _amount * saleInfo.salePrice, "your pay not enough");
        
        
        if (saleInfo.saleAmount != _amount) {
            //갯수를 다르게 산다면...
            onSaleInfos[_orderId] = Xcube.OnSaleInfo(saleInfo.orderId, saleInfo.workId, saleInfo.seller, saleInfo.saleAmount - _amount, saleInfo.salePrice);
            onSaleInfosOfAddress[saleInfo.seller][saleInfo.orderId] = Xcube.OnSaleInfo(saleInfo.orderId, saleInfo.workId, saleInfo.seller, saleInfo.saleAmount - _amount, saleInfo.salePrice);
            
        } else {
            //같다면.. 다 산거니까..
            
            removeOnSaleOrderIds(_orderId); //판매 중인 orderIds에서 제거    
            delete onSaleInfos[_orderId]; //판매 상세 목록에서 제거
            delete onSaleInfosOfAddress[saleInfo.seller][_orderId]; //해당주소가 팔고 있는 정보 삭제
        }

        //event purchase(address seller, address buyer, uint256 orderId, uint256 workId, uint256 saleAmount, uint256 buyAmout, uint256 salePrice, uint256 buyPrice);
        emit purchase(saleInfo.seller, msg.sender, _orderId, saleInfo.workId, saleInfo.saleAmount, _amount, saleInfo.salePrice, msg.value);

        payable(saleInfo.seller).transfer(msg.value);
        xcube.safeTransferFrom(saleInfo.seller, msg.sender, saleInfo.workId, _amount, "");

        //seller update
        Xcube.WorkDetail memory workDetail = xcube.getWorkDetailsOfOwner(saleInfo.seller, saleInfo.workId);
        uint256 lastHaveAmout = workDetail.currentHaveAmount - saleInfo.saleAmount;
        if(lastHaveAmout == 0) {
            //가지고 있는걸 다 판거야...
            xcube.removeWorkOfOwner(saleInfo.seller, saleInfo.workId); //주소가 소유한 작품에서 뺀다.
            xcube.deleteWorkDetailsOfOwner(saleInfo.seller, saleInfo.workId); //주소가 소유한 작품의 상세 정보를 뺀다.
        } else {
            //조금 남았어...
            xcube.setWorkDetailsOfOwner(workDetail.owner, workDetail.workId, xcube.balanceOf(workDetail.owner, saleInfo.workId), workDetail.currentPrice); //주소가 소유한 작품의 상세 정보를 수정
        }

        //buyer update
        xcube.addWorkOfOwner(msg.sender, saleInfo.workId);
        xcube.addWorkDetailsOfOwner(msg.sender, saleInfo.workId, _amount, msg.value / _amount);
        this.setMaxSaleAbleCountOfWorks(msg.sender, workDetail.workId, _amount);
    }

    function getMaxSaleAbleCountOfWorks(address owner, uint256 _workId) view private returns (uint256) {
        uint256 res = maxSaleAbleCountOfWorks[owner][_workId];
        return res;
    }

    function setMaxSaleAbleCountOfWorks(address owner, uint256 _workId, uint256 _amount) external {
        maxSaleAbleCountOfWorks[owner][_workId] = _amount;
    }

    //판매중인 작품 리스트
    function getOnSaleOrderIds() view external returns (uint256[] memory) {
        return onSaleOrderIds;
    }

    //판매중인 작품 상세 정보
    function getOnSaleInfo(uint256 _orderId) view external returns (Xcube.OnSaleInfo memory) {
        return onSaleInfos[_orderId];
    }
    
    function addOnSaleOrderIds(uint256 _orderId) private {
        isContainsOrderId[_orderId] = true;
        onSaleOrderIds.push(_orderId);
    }

    function getIsContainsOrderId(uint256 _orderId) view private returns (bool) {
        return isContainsOrderId[_orderId];
    }

    function removeOnSaleOrderIds(uint256 _orderId) private {
        delete isContainsOrderId[_orderId];
        for(uint256 i = 0; i < onSaleOrderIds.length; i++) {
            if(onSaleOrderIds[i] == _orderId) {
                onSaleOrderIds[i] = 0;
                break;
            }
        }
        for(uint256 i = 0; i < onSaleOrderIds.length; i++) {
            if(onSaleOrderIds[i] == 0) {
                onSaleOrderIds[i] = onSaleOrderIds[onSaleOrderIds.length - 1];
                onSaleOrderIds.pop();
                break;
            }
        }
    }

    
}
