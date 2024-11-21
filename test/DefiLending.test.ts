import { ethers } from "hardhat";
import { expect } from "chai";
import { DefiLending, PriceFeed, BTZToken } from "../typechain-types";
import { Signer } from "ethers";

describe("DefiLending Contract", function () {
  let defiLending: DefiLending;
  let priceFeed: PriceFeed;
  let btzToken: BTZToken;
  let owner: Signer;
  let user: Signer;
  let collateralTokenAddress: string;
  let priceFeedAddress: string;
  let loanInterest: number;

  beforeEach(async () => {
    [owner, user] = await ethers.getSigners();

    const bTZTokenFactory = await ethers.getContractFactory("BTZToken");
    btzToken = await bTZTokenFactory.deploy();

    const priceFeedFactory = await ethers.getContractFactory("PriceFeed");
    priceFeed = await priceFeedFactory.deploy();

    collateralTokenAddress = await btzToken.address;

    priceFeedAddress = await priceFeed.address;
    loanInterest = 5;

    // Deploy the DefiLending contract
    const defiLendingFactory = await ethers.getContractFactory("DefiLending");
    defiLending = await defiLendingFactory.deploy();

    await btzToken.mint(await user.address, 10000000000000);
    await btzToken.mint(await defiLending.address, 10000000000000);

    console.log(await defiLending.address);
    console.log(await user.address);
    console.log(await owner.address);

    // Initialize DefiLending contract
    await defiLending.initialize(
      await btzToken.address,
      collateralTokenAddress,
      priceFeedAddress,
      loanInterest
    );
  });

  it("should deploy contracts successfully", async () => {
    expect(await defiLending.owner()).to.equal(await owner.address);
    expect(await defiLending.getLoanInterest()).to.equal(loanInterest);
  });

  it("should allow users to deposit collateral and borrow money", async () => {
    const loanAmount = 1000;
    const collateralAmount = 2000;

    await btzToken
      .connect(user)
      .approve(await defiLending.address, collateralAmount);

    await defiLending
      .connect(user)
      .depositCollateralAndBorrow(
        { tokenAddress: await btzToken.address, tokenAmount: collateralAmount },
        loanAmount
      );

    const loanBalance = await defiLending.getTotalMoneyOnLoanByUser(
      await user.address
    );
    const collateralBalance = await defiLending.getCollateralsByUser(
      await user.address
    );

    expect(loanBalance).to.equal(loanAmount);
    expect(collateralBalance).to.equal(collateralAmount);
  });

  it("should calculate correct loan interest", async () => {
    const loanAmount = 1000;
    const collateralAmount = 2000;

    await btzToken
      .connect(user)
      .approve(await defiLending.address, collateralAmount);

    await defiLending
      .connect(user)
      .depositCollateralAndBorrow(
        { tokenAddress: await btzToken.address, tokenAmount: collateralAmount },
        loanAmount
      );

    // Check loan interest calculation
    await defiLending.recalculateLoanInterest();

    const updatedLoanAmount = await defiLending.getTotalMoneyOnLoanByUser(
      await user.address
    );
    const expectedAmount = loanAmount * 1.05;

    expect(updatedLoanAmount).to.equal(expectedAmount);
  });

  it("should allow owner to execute liquidation", async () => {
    const userAddress = await user.address;
    const loanAmount = 1000;
    const collateralAmount = 1000;

    await btzToken
      .connect(user)
      .approve(await defiLending.address, collateralAmount);

    await defiLending
      .connect(user)
      .depositCollateralAndBorrow(
        { tokenAddress: await btzToken.address, tokenAmount: collateralAmount },
        loanAmount
      );

    // No liquidation should happen
    await defiLending.connect(owner).checkLiquidations();

    const loanBalance = await defiLending.getTotalMoneyOnLoanByUser(
      userAddress
    );
    const collateralBalance = await defiLending.getCollateralsByUser(
      userAddress
    );

    expect(loanBalance).to.equal(loanAmount);
    expect(collateralBalance).to.equal(collateralAmount);
  });

});
