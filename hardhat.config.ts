import { HardhatUserConfig } from "hardhat/config";
import "hardhat-deploy";
import "@nomiclabs/hardhat-ethers";
import "hardhat-contract-sizer";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import * as dotenv from "dotenv";

dotenv.config();

const accounts = process.env.PRIVATE_KEY == undefined ? [] : [process.env.PRIVATE_KEY];

const config: HardhatUserConfig = {

  namedAccounts: {
    deployer: {
      default: 0,
      filecoin: "0x3BBFa3feDbb53323CD2beb754f20bDbb87D04bc1",
      hyperspace: "0x49554923b9361e158Fb267B436f843a4f537D53a",
    },
  },
  defaultNetwork: "hardhat",
  networks: {
    filecoin: {
      url: "https://api.node.glif.io",
      chainId: 314,
      accounts,
    },
    hyperspace: {
      url: "https://rpc.ankr.com/filecoin_testnet",
      chainId: 3141,
      accounts,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  mocha: {
    timeout: 100000000
  },
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v5",
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    externalArtifacts: ["externalArtifacts/*.json"], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
    dontOverrideCompile: false, // defaults to false
  },
};


export default config;
