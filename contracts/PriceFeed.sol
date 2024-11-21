// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol';

contract PriceFeed {

    AggregatorV3Interface internal dataFeed;

    constructor(){
        dataFeed=AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }

    function getLatestEthPriceInUSD() public view returns(int){
        // (,int answer,,,)=dataFeed.latestRoundData();
        // return answer;
        //TODO use getChainlinkDataFeedLatestAnswer properly when oracle is implemented
        return 1;
    }
    
    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int256 answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }

}