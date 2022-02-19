// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IMasonry.sol";
import "./interfaces/ITShareRewardPool.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TombVanillaCompounder is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Tokens
    IERC20 public tomb;
    IERC20 public tshare;
    IUniswapV2Pair public spookyTombFtmLP;

    // Tomb's smart contracts
    IMasonry public masonry;
    ITShareRewardPool public cemetery;

    // SpookySwap's smart contracts
    IUniswapV2Router02 public spookyRouter;

    constructor(
        address _tomb,
        address _tshare,
        address _spookyTombFtmLP,
        address _masonry,
        address _cemetery,
        address _spookyRouter,
        address _operator,
        address _profit
    ) {
        tomb = IERC20(_tomb);
        tshare = IERC20(_tshare);
        spookyTombFtmLP = IUniswapV2Pair(_spookyTombFtmLP);
        masonry = IMasonry(_masonry);
        cemetery = ITShareRewardPool(_cemetery);
        spookyRouter = IUniswapV2Router02(_spookyRouter);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, _operator);
    }
    address constant public wrapped = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83); //wftm token
    address constant public output = address(0x7a6e4E3CC2ac9924605DCa4bA31d1831c84b44aE); //2omb token
    address[] public outputToWrappedRoute = [output, wrapped]; //route
    
    uint256 profitPercent = 10;


    // Fallback payable function
    receive() external payable {}
    
    //set profit taking percentage
    function setProfit(uint256 _profitPercent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        profitPercent = _profitPercent;
    }

    // Getters for balances at Tomb against this contract's address
    function getTSHAREBalanceAtTombMasonry() public view returns (uint256) {
        return masonry.balanceOf(address(this));
    }

    function getLPBalanceAtTombCemetery() public view returns (uint256) {
        (uint256 amount, ) = cemetery.userInfo(0, address(this));
        return amount;
    }

    // Functions to withdraw tokens only from this contract
    function withdrawDustFTM() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(this).balance > 0, "No dust FTM to withdraw!");
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawDustTOMB() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tomb.balanceOf(address(this)) > 0, "No dust TOMB to withdraw!");
        tomb.safeTransfer(msg.sender, tomb.balanceOf(address(this));
    }
    
    function withdrawDustWrapped() external onlyRole(DEFAULT_ADMIN_ROLE) 
        require(wrapped.balanceOf(address(this)) > 0, "No dust WFTM to withdraw!");
        wrapped.safeTransfer(msg.sender, wrapped.balanceOf(address(this));
    }

    function _claimAnyTSHARERewardsFromCemetery() internal {
        // calling withdraw with amount as 0 simply claims any pending TSHAREs
        cemetery.withdraw(0, 0);
    }

    function _claimAnyTOMBRewardsFromMasonryIfAllowed() internal {
        if (masonry.earned(address(this)) > 0 && masonry.canClaimReward(address(this))) {
            masonry.claimReward();
        }
    }

    function _depositAnyTSHAREIntoMasonry() internal {
        uint256 contractTSHAREBalance = tshare.balanceOf(address(this));
        if (contractTSHAREBalance > 0) {
            tshare.safeIncreaseAllowance(address(masonry), contractTSHAREBalance);
            masonry.stake(contractTSHAREBalance);
        }
    }

    // should probably remove in favor of _swapHalfToken1ForToken2 and refactor usages
    function _swapHalfTOMBForFTM() internal {
        uint256 contractTOMBBalance = tomb.balanceOf(address(this));
        if (contractTOMBBalance > 0) {
            uint256 halfTOMB = contractTOMBBalance / 2;
            tomb.approve(address(spookyRouter), halfTOMB);

            address[] memory path = new address[](2);
            path[0] = address(tomb);
            path[1] = spookyRouter.WETH();

            spookyRouter.swapExactTokensForETH(halfTOMB, 0, path, address(this), block.timestamp);
        }
    }
    
    // Adds liquidity to AMM and gets more LP tokens.
    function _addLiquidity() internal {
        uint256 outputHalf = tomb.balanceOf(address(this)).div(2);
        if (contractTOMBBalance > 0) {
            tomb.approve(address(spookyRouter), halfTOMB);

            address[] memory path = new address[](2);
            path[0] = address(tomb);
            path[1] = spookyRouter.WETH();

            spookyRouter.swapExactTokensForETH(halfTOMB, 0, path, address(this), block.timestamp);
            
            uint256 contractTOMBBalance = tomb.balanceOf(address(this));
            uint256 contractFTMBalance = address(this).balance;
        
            tomb.approve(address(spookyRouter), contractTOMBBalance);
        
            spookyRouter.addLiquidityETH{value: contractFTMBalance}(address(tomb), contractTOMBBalance, 1, 1, address(this), block.timestamp);
        
        }
    }

    function _swapHalfToken1ForToken2(IERC20 _token1, IERC20 _token2) internal {
        uint256 contractToken1Balance = _token1.balanceOf(address(this));
        if (contractToken1Balance > 0) {
            uint256 halfToken1 = contractToken1Balance / 2;
            _token1.approve(address(spookyRouter), halfToken1);

            address[] memory path = new address[](2);
            path[0] = address(_token1);
            path[1] = address(_token2);

            uint[] memory amountOutMins = spookyRouter.getAmountsOut(halfToken1, path);
            uint256 minToken2Expected = amountOutMins[1] - ((slippageInTenthOfPercent * amountOutMins[1]) / 1000);

            spookyRouter.swapExactTokensForTokens(halfToken1, minToken2Expected, path, address(this), block.timestamp);
        }
    }

    function _addFTMTOMBLiquidity() internal {
        uint256 contractTOMBBalance = tomb.balanceOf(address(this));
        uint256 contractFTMBalance = address(this).balance;

        tomb.approve(address(spookyRouter), contractTOMBBalance);

        spookyRouter.addLiquidityETH{value: contractFTMBalance}(address(tomb), contractTOMBBalance, 1, 1, address(this), block.timestamp);
    }

    function _depositAnyLPIntoCemetery() internal {
        uint256 contractLPBalance = spookyTombFtmLP.balanceOf(address(this));
        if (contractLPBalance > 0) {
            spookyTombFtmLP.approve(address(cemetery), contractLPBalance);
            cemetery.deposit(0, contractLPBalance);
        }
    }
    
    function _takeProfit() internal {
        uint256 outputTakeProfit = (tomb.balanceOf(address(this)) * profitPercent) / 100;
        if (outputTakeProfit > 0) {
            tomb.approve(address(spookyRouter), outputTakeProfit);

            spookyRouter.swapExactTokensForTokens(outputTakeProfit, 0, outputToWrappedRoute, address(this), now);
            uint256 wrappedBal = IERC20(wrapped).balanceOf(address(this));
        
            IERC20(wrapped).safeTransfer(profit, wrappedBal);
        }
    }
}
