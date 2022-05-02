// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Xcube.sol";

contract SaleNftToken {
    Xcube public xcube;

    constructor (address _xcubeTokenAddress) {
        xcube = Xcube(_xcubeTokenAddress);
    }

    uint256[] private onSaleWorkArray; //판매 중인 작품...
    mapping(uint256 => bool) private isOnSaleWork;
    mapping(uint256 => Xcube.SaleInfo[]) private saleWorkInfos; //판매 중인 작품의 판매 정보
    mapping(address => uint256[]) private onSaleWorkOfAddress;// 주소가 팔고 있는 리스트 필요
    mapping(address => mapping(uint256 => uint256)) private onSaleCountOfWorks;// 주소가 팔고 있는 작품의 판매중 인 갯수
    
    //uint256[] private onSaleEditionArray; //판매중인 에디션리스트...필요


    //work 를 팔기 위해 사용
    function setForSaleWork(uint256 _workId, uint256 _numberOfSales, uint256 _salePrice) public {
        require(xcube.isApprovedForAll(msg.sender, address(this)), "NFT token owner did not approve SaleNftToken.");
        require(_salePrice > 0, "salePrice is is must hight than zero.");
        require(_numberOfSales > 0, "numberOfSale is must hight than zero.");

        uint256 balance = xcube.balanceOf(msg.sender, _workId);
        require(balance != 0, "You have not Work.");
        uint256 saleCountOfWork = onSaleCountOfWorks[msg.sender][_workId]; //이미 해당 작품으로 팔고 있는 갯수
        uint256 lastAmount = balance - saleCountOfWork; //판매가능한 양
        require(lastAmount >= _numberOfSales, "You have not enough amount."); //판매가능한 개수가 판매하려는 개수보다 크거나 같아야한다.
        
        addSaleWorkArray(_workId);
        saleWorkInfos[_workId].push(Xcube.SaleInfo(msg.sender, _numberOfSales, _salePrice));
        onSaleWorkOfAddress[msg.sender].push(_workId);
        onSaleCountOfWorks[msg.sender][_workId] = _numberOfSales;
    }

    function addSaleWorkArray(uint _workId) private {
        if(containsOfIsOnSaleWork(_workId) == false) {
            onSaleWorkArray.push(_workId);
            setIsOnSaleWork(_workId);
        }
    }

    function setIsOnSaleWork(uint256 _workId) private {
        isOnSaleWork[_workId]=true;
    }

    function containsOfIsOnSaleWork(uint256 _workId) view private returns (bool){
        return isOnSaleWork[_workId];
    }

    //판매중인 작품 리스트
    function getOnSaleWorkArray() view public returns (uint256[] memory) {
        return onSaleWorkArray;
    }

    //판매중인 작품의 판매 정보 개수
    function getOnSaleWorkInfoSize(uint256 _workId) view public returns (uint256 total) {
        Xcube.SaleInfo[] memory saleInfos = saleWorkInfos[_workId];
        return saleInfos.length;
    }

    //판매중인 작품의 판매 정보
    function getOnSaleWorkInfo(uint256 _workId) view public returns (Xcube.SaleInfo[] memory saleInfos) {
        return saleWorkInfos[_workId];
    }
/*
    //판매중인 작품 개수
    function getOnSaleWorkArrayLength() view public returns (uint256) {
        return onSaleWorkArray.length;
    }


    //판매중인 에디션 개수
    function getOnSaleEditionArrayLength() view public returns (uint256) {
        return onSaleEditionArray.length;
    }

    //판매중인 에디션 리스트
    function getOnSaleEditionArrayArray() view public returns (uint256[] memory) {
        return onSaleEditionArray;
    }

    //edition 가격 가져오기
    function getNftTokenPrice(uint256 editionId) view public returns (uint256) {
        return editionsPrices[editionId];
    }


    //NFT 를 사기 위해 사용
    function purchaseEdition(uint256 workId, uint256[] _editionObid, uint256[] _pay) public payable {
        uint256 totalPay = 0;
        for (uint256 i = 0; i < _editionObid.length; i++) {
            uint256 price = editionsPrices[_editionObid];
            require(price > 0, "NFT token is not on sale.");
            totalPay += _pay[i];
        }
        require(totalPay == msg.value, "you must equal _pay and totalPay");
        for (uint256 i = 0; i < _editionObid.length; i++) {
            address editionOnwer = xcube.ownerOf(_editionObid);
            require(editionOnwer != msg.sender, "You are this NFT token owner.");
        }
        for (uint256 i = 0; i < _editionObid.length; i++) {
            address editionOnwer = xcube.ownerOf(_editionObid);
            payable(editionOnwer).transfer(_pay[i]);
        }
        xcube.safeTransferFrom(editionOnwer, msg.sender, workId, _editionObid.length, "");


        //xcube.setTokenOwners(_nftTokenId, msg.sender);
        nftTokenPrices[_nftTokenId] = 0;

        for(uint256 i = 0; i < onSaleNftTokenArray.length; i++) {
            if(nftTokenPrices[onSaleNftTokenArray[i]] == 0) {
                onSaleNftTokenArray[i] = onSaleNftTokenArray[onSaleNftTokenArray.length - 1];
                onSaleNftTokenArray.pop();
            }
        }

    }
*/
    

}