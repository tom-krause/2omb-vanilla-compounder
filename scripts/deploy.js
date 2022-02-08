 const TombAddress = "0x7a6e4E3CC2ac9924605DCa4bA31d1831c84b44aE"; //2omb
 const TShareAddress = "0xc54A1684fD1bef1f077a336E6be4Bd9a3096a6Ca"; //2share
 const SpookyTombFtmLPAddress = "0xbdC7DFb7B88183e87f003ca6B5a2F81202343478";
 const MasonryAddress = "0x627A83B6f8743c89d58F17F994D3F7f69c32F461"; //boardroom 2omb reward
 const CemeteryAddress = "0x8D426Eb8C7E19b8F13817b07C0AB55d30d209A96"; //2share reward pool "farms"
 const SpookyRouterAddress = "0xF491e7B69E4244ad4002BC14e878a34207E38c29";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const factory = await ethers.getContractFactory("TombVanillaCompounder");
  const contract = await factory.deploy(
    TombAddress,
    TShareAddress,
    SpookyTombFtmLPAddress,
    MasonryAddress,
    CemeteryAddress,
    SpookyRouterAddress,
  );

  console.log("Contract address:", contract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
