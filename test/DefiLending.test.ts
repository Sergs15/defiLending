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

    collateralTokenAddress =await btzToken.getAddress();

    priceFeedAddress = await priceFeed.getAddress();
    loanInterest = 5;

    // Deploy the DefiLending contract
    const defiLendingFactory = await ethers.getContractFactory("DefiLending");
    defiLending = await defiLendingFactory.deploy();
    await defiLending.waitForDeployment();

    // Initialize DefiLending contract
    await defiLending.initialize(
      await btzToken.getAddress(),
      collateralTokenAddress,
      priceFeedAddress,
      loanInterest
    );
  });

  it("should deploy contracts successfully", async () => {
    expect(await defiLending.owner()).to.equal(await owner.getAddress());
    expect(await defiLending.getLoanInterest()).to.equal(loanInterest);
  });

  it("should allow users to deposit collateral and borrow money", async () => {
    const loanAmount = 1000;
    const collateralAmount = 2;

    await btzToken
      .connect(user)
      .approve(await defiLending.getAddress(), collateralAmount);

    await defiLending
      .connect(user)
      .depositCollateralAndBorrow(
        { tokenAddress: collateralTokenAddress, tokenAmount: collateralAmount },
        loanAmount
      );

    const loanBalance = await defiLending.getTotalMoneyOnLoanByUser(
      await user.getAddress()
    );
    const collateralBalance = await defiLending.getCollateralsByUser(
      await user.getAddress()
    );

    expect(loanBalance).to.equal(loanAmount);
    expect(collateralBalance).to.equal(collateralAmount);
  });

  it("should calculate correct loan interest", async () => {
    const userAddress = await user.getAddress();
    const initialLoanAmount = 1000;

    // Simulate user borrowing
    await defiLending.connect(user).borrow(initialLoanAmount);

    // Check loan interest calculation
    await defiLending.recalculateLoanInterest();

    const updatedLoanAmount = await defiLending.getTotalMoneyOnLoanByUser(
      userAddress
    );
    const expectedAmount = initialLoanAmount * 1.05;

    expect(updatedLoanAmount).to.equal(expectedAmount);
  });

  it("should allow owner to execute liquidation", async () => {
    const userAddress = await user.getAddress();
    const collateralAmount = 1;

    // User deposits collateral
    await defiLending.connect(user).depositCollateral({
      tokenAddress: collateralTokenAddress,
      tokenAmount: collateralAmount,
    });

    // Trigger liquidation if collateral value is less than loan
    await defiLending.connect(owner).checkLiquidations();

    // Ensure liquidation happens (collateral should be zero after liquidation)
    const loanBalance = await defiLending.getTotalMoneyOnLoanByUser(
      userAddress
    );
    const collateralBalance = await defiLending.getCollateralsByUser(
      userAddress
    );

    expect(loanBalance).to.equal(0);
    expect(collateralBalance).to.equal(0);
  });
});
