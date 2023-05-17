import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getMaxPriorityFeePerGas } from "../utils/callRpc";

 
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, ethers, getNamedAccounts, network } = hre;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.getSigner(deployer);

    let maxPriorityFeePerGas = ethers.BigNumber.from(Math.ceil(parseInt(await getMaxPriorityFeePerGas(network.name)) * 1.25));
    console.log(`now ${network.name} maxPriorityFeePerGas is: ${maxPriorityFeePerGas}`);

    // deploy ProxyAdmin contract
    const ProxyAdminResult = await deployments.deploy("ProxyAdmin", {
        from: deployer,
        args: [],
    });
    console.log(`ProxyAdmin contract address: ${ProxyAdminResult.address}`);

    // deploy Fundraising contract
    const FundraisingResult = await deployments.deploy("Fundraising", {
        from: deployer,
        args: [],
        maxPriorityFeePerGas,
    });
    console.log(`Fundraising contract address: ${FundraisingResult.address}`);
    // get ProxyAdmin contract
    const ProxyAdminDeployment = await deployments.get("ProxyAdmin");
    // deploy Proxy contract
    const ProxyResult = await deployments.deploy("FundraisingProxy", {
        from: deployer,
        args: [FundraisingResult.address, ProxyAdminDeployment.address, "0x"],
        contract: "TransparentUpgradeableProxy",
        maxPriorityFeePerGas,
    });
    console.log(`Proxy contract address: ${ProxyResult.address}`);
    const Fundraising = await ethers.getContractAt("Fundraising", ProxyResult.address, signer);
    const initializeTx = await Fundraising.initialize( deployer, deployer, { maxPriorityFeePerGas });
    await initializeTx.wait();
    console.log('Fundraising contract initilize successfully.');
}

export default func;
func.tags = ["Fundraising"];