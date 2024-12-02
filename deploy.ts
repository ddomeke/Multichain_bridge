import { ethers } from "ethers";
import * as dotenv from "dotenv";
import { readFileSync } from "fs";

dotenv.config();

async function main() {
    console.log("Deploying the MultichainControl contract...");

    // RPC URL ve özel anahtar
    const RPC_URL = process.env.RPC_URL;
    const PRIVATE_KEY = process.env.PRIVATE_KEY;

    if (!RPC_URL || !PRIVATE_KEY) {
        throw new Error("Missing environment variables or parameters: Ensure RPC_URL, PRIVATE_KEY are provided");
    }

    // Sağlayıcı ve cüzdan oluşturma
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

    // MccbToken kontratının bytecode ve ABI'si
    const tokenContractJson = JSON.parse(
        readFileSync("./artifacts/contracts/MccbToken.sol/MccbToken.json", "utf-8")
    );
    const tokenBytecode = tokenContractJson.bytecode;
    const tokenAbi = tokenContractJson.abi;

    // Kontrat Factory'sini oluşturun
    const TokenContractFactory = new ethers.ContractFactory(tokenAbi, tokenBytecode, wallet);

    // Başlangıç arzını belirle (örneğin: 1 milyon token)
    const initialSupply = ethers.parseUnits("1000000", 18); // 1 milyon token, 18 decimal

    // MccbToken kontratını deploy edin
    const tokenContract = await TokenContractFactory.deploy(initialSupply);

    console.log("Transaction hash:", tokenContract.deploymentTransaction()?.hash);

    await tokenContract.deploymentTransaction()?.wait();

    console.log("tokenContract  deployed to:", tokenContract.target);


    // Derlenmiş kontrat bytecode ve ABI
    const contractJson = JSON.parse(
        readFileSync("./artifacts/contracts/MultichainControl.sol/MultichainControl.json", "utf-8")
    );
    const bytecode = contractJson.bytecode;
    const abi = contractJson.abi;

    // Kontrat Factory'sini oluşturun
    const ContractFactory = new ethers.ContractFactory(abi, bytecode, wallet);

    // Kontratı deploy edin
    const contract = await ContractFactory.deploy(); // Parametreleri array içinde geçin    
    await contract.waitForDeployment();
    const contractAddress = await contract.getAddress();
    console.log("MetaTransaction contract deployed to:", contractAddress);

    
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Error deploying contract:", error);
        process.exit(1);
    });
