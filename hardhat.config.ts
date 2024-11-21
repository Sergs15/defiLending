import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from 'dotenv';
import "@chainlink/hardhat-chainlink";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  defaultNetwork: "hardhat"
};

export default config;
