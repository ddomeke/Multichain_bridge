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

    console.log("Transaction hash:", contract.deploymentTransaction()?.hash);

    await contract.deploymentTransaction()?.wait();

    console.log("MetaTransaction contract deployed to:", contract.target);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Error deploying contract:", error);
        process.exit(1);
    });
