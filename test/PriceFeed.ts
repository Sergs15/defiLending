import { expect } from "chai";
import { ethers } from "hardhat";
import { PriceFeed } from "../typechain-types";

describe("PriceFeed", function () {
  let contract: PriceFeed;

  beforeEach(async () => {
    const PriceFeed = await ethers.getContractFactory("PriceFeed");
    contract = await PriceFeed.deploy();
  });

  // ...

  describe("getOracleValue", () => {
    it("return value", async () => {
      const result = await contract.getChainlinkDataFeedLatestAnswer();
      console.log(result);
    });
  });

  // ...
});
