const { network, ethers } = require(`hardhat`);
const fs = require(`fs`);

const feeRewardAddress = `0x04eFD76283A70334C72BB4015e90D034B9F3d245`;
// const tokensList = `./tokens.json`;

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer address: ${deployer.address}`);
  let nonce =
    (await network.provider.send(`eth_getTransactionCount`, [
      deployer.address,
      "latest",
    ])) - 1;

  let SwapFeeReward = await ethers.getContractFactory(`SwapFeeRewardWithRB`);
  let swapFeeReward = await SwapFeeReward.attach(feeRewardAddress);

  // console.log(`Add tokens to white list in swap fee reward`);
  // let tokens = fs.readFileSync(tokensList, "utf-8");
  // tokens = JSON.parse(tokens);
  //
  // for (const item of tokens) {
  //     console.log(`Try to add token ${item.name} address ${item.address} to contract`);
  //     console.log(`nonce: `, nonce);
  //     let tx = await swapFeeReward.addWhitelist(item.address, {nonce: ++nonce, gasLimit: 3000000});
  //     await tx.wait();
  // }
  //function setPair(uint256 _pid, uint256 _percentReward)
  //function setPairEnabled(uint256 _pid, bool _enabled)

  console.log(`Change fee return percent`);
  const pairPercent = [
    {pid: 0, percent: 10},
    {pid: 1, percent: 10},
    {pid: 2, percent: 10},
    {pid: 3, percent: 10},
    {pid: 4, percent: 10},
    {pid: 5, percent: 10},
    {pid: 6, percent: 10},
    {pid: 7, percent: 10},
    {pid: 8, percent: 10},
    {pid: 9, percent: 10},
    {pid: 11, percent: 10},
    {pid: 10, percent: 10},
    {pid: 12, percent: 10},
    {pid: 13, percent: 10},
    {pid: 16, percent: 10},
    {pid: 18, percent: 10},
    {pid: 19, percent: 10},
    {pid: 20, percent: 10},
    {pid: 21, percent: 10},
    {pid: 22, percent: 10},
    {pid: 23, percent: 10},
    {pid: 24, percent: 10},
    {pid: 25, percent: 10},
    {pid: 26, percent: 10},
    {pid: 29, percent: 100},
    {pid: 32, percent: 10},
    {pid: 33, percent: 10},
    {pid: 34, percent: 10},
    {pid: 35, percent: 10},
    {pid: 36, percent: 10},
    {pid: 37, percent: 10},
    {pid: 38, percent: 10},
    {pid: 39, percent: 10},
    {pid: 40, percent: 10},
    {pid: 41, percent: 10},
    {pid: 42, percent: 10},
    {pid: 43, percent: 10},
    {pid: 44, percent: 10},
    {pid: 45, percent: 10},
    {pid: 46, percent: 10},
    {pid: 47, percent: 10},
    {pid: 48, percent: 10},
    {pid: 49, percent: 10},
    {pid: 50, percent: 10},
    {pid: 51, percent: 10},
    {pid: 52, percent: 10},
    {pid: 53, percent: 10},
    {pid: 54, percent: 10},
    {pid: 55, percent: 10},
    {pid: 56, percent: 10},
    {pid: 58, percent: 10},
    {pid: 59, percent: 10},
    {pid: 60, percent: 10},
    {pid: 62, percent: 10},
    {pid: 63, percent: 10},
    {pid: 64, percent: 10},
    {pid: 65, percent: 10},
  ]
  for(const item of pairPercent) {
    await swapFeeReward.setPair(
      item.pid,
      item.percent,
      {nonce: ++nonce, gasLimit: 3000000}
    );

    console.log(`Pair pid: ${item.pid} percent changed to: ${item.percent}`);
  }

  // console.log(`Remove pairs from feeReward`);
  // let pidsToRemove = [15];
  // for (const item of pidsToRemove) {
  //   let tx = await swapFeeReward.setPairEnabled(item, false, {
  //     nonce: ++nonce,
  //     gasLimit: 3000000,
  //   });
  //
  // }

  // console.log(`Add pairs to swap fee reward`);
  // let pairs = [
  //   `0x1Cba970a6E06d4BcC0c4717BE677d1A8AA0211DA` // ETC - BNB
  // ];
  // for (const item of pairs) {
  //   await swapFeeReward.addPair(5, item, {
  //     nonce: ++nonce,
  //     gasLimit: 3000000,
  //   });
  //
  //   console.log(`Pair with address ${item} percent 29 added`);
  // }

  // let pairs = fs.readFileSync(`./Pair list.json`, "utf-8");
  // pairs = JSON.parse(pairs);
  //
  // for (const item of pairs) {
  //     if (item.enabled) {
  //         console.log(`Try add pair ${item.name.symbolA}/${item.name.symbolB} with address ${item.address} percent ${item.percent}`);
  //         console.log(`nonce: `, nonce);
  //         let tx = await swapFeeReward.addPair(item.percent, item.address, {nonce: ++nonce, gasLimit: 3000000});
  //         await tx.wait();
  //     }
  // }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
