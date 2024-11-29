import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";
import * as dotenv from "dotenv";

// .env dosyasındaki değerleri içe aktarır
dotenv.config();

const config: HardhatUserConfig = {
  solidity:{
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    sepolia: {
      url: process.env.RPC_URL || "", // .env'den RPC URL'sini alır
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [], // Private key dizisi
    },
  },
};

export default config;
