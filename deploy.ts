import {ethers} from 'hardhat'
import { BTZToken, DefiLending } from './typechain-types';
import {config} from 'dotenv'

const main = async() => {
    const env = config({path:'process.env'});

    const collateralTokenAddress = env.parsed?.COLLATERAL_TOKEN_ADDRESS ?? "";
    const priceFeedAddress = env.parsed?.PRICE_FEED_ADDRESS ?? "";
    const loanInterest = ethers.toBigInt(env.parsed?.LOAN_INTEREST ?? "0");

    const btz = await ( await ethers.getContractFactory('BTZToken')).deploy() as BTZToken;
    await btz.waitForDeployment();
    console.log("btz: " + await btz.getAddress())

    const defiLending = await ( await ethers.getContractFactory('DefiLending')).deploy() as DefiLending;
    await defiLending.waitForDeployment();
    console.log("defiLending: " + await btz.getAddress())

    await defiLending.initialize(
        await btz.getAddress(),
        collateralTokenAddress,
        priceFeedAddress,
        loanInterest);
}