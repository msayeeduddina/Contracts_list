import hre from 'hardhat';

async function main() {
  const deployer = (await hre.ethers.getSigners())[0];
  const factory = await hre.ethers.getContractFactory('AcceptsContractSignaturesForwarder', deployer);
  const deployment = await factory.deploy();
  console.log(`Deployed AcceptsContractSignaturesForwarder at ${deployment.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
