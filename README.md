# tomb-vanilla-compounder

### Prerequisite knowledge
- General smart contract programming using Solidity and hardhat
- Tomb's Cemetery and Masonry contracts to understand our interactions with them
- ethers for scripts to test, deploy, and harvest (javascript)
- (Bonus) ~~AWS Lambda to be able to automate harvesting every 18 hours~~ Use Gelato tasks to automate harvesting every 6hrs

### "Simple" solo-use smart contract to automate the "tomb-loop":
1. Claim TSHARE rewards from Cemetery
2. Claim TOMB rewards from Masonry
3. Deposit TSHARE rewards into Masonry
4. Take profit from TOMB rewards for WFTM, profit percentage is adjustable default set at 10%
5. Swap half of the TOMB rewards for FTM, and convert into Spooky FTM-TOMB LP tokens
6. Deposit LP tokens into Cemetery

### Key Solidity files

- The main smart contract of interest is `TombSoloCrypt`. This is the one you want to deploy to mainnet. Anybody can deposit LP tokens or TSHAREs into it, but only the owner can withdraw any tokens. The function `runRoutine()` is the one that executes the "tomb-loop."
- A lot of the internal functions have been abstracted away and pulled up into a base contract called `TombVanillaCompounder`.
- You can ignore `TombMultiCrypt`

### Key javascript files

- `deploy.js` to deploy to your network of choosing (configure networks in `hardhat.config.js`)
- `index.js` in the `harvester/` folder to invoke `runRoutine()` (the `harvester/` folder is written with an AWS Lambda setup in mind)

**You need to add a .env file that contains two variables, `DEPLOYER_PRIVATE_KEY`(without the leading `0x`) and `FTMSCAN_API_KEY`, for the project to build.**
