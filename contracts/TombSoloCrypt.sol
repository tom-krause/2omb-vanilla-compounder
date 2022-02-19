// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TombVanillaCompounder.sol";

contract TombSoloCrypt is TombVanillaCompounder {
    using SafeERC20 for IERC20;

    constructor(
        address _tomb,
        address _tshare,
        address _spookyTombFtmLP,
        address _masonry,
        address _cemetery,
        address _spookyRouter,
        address _operator
    ) TombVanillaCompounder(
        _tomb,
        _tshare,
        _spookyTombFtmLP,
        _masonry,
        _cemetery,
        _spookyRouter,
        _operator
    ) { }

    // Deposit LPs into this contract, which then get deposited into Tomb's Cemetery
    // The caller must have approved this contract to spend the LPs beforehand
    function depositLP(uint256 _amount) external {
        require(spookyTombFtmLP.allowance(msg.sender, address(this)) >= _amount, "Don't have allowance for this amount!");
        spookyTombFtmLP.transferFrom(msg.sender, address(this), _amount);
        spookyTombFtmLP.approve(address(cemetery), _amount);
        cemetery.deposit(0, _amount);
    }

    // Functions to withdraw tokens both from this contract and from Tomb
    function withdrawTSHARE() external onlyRole(DEFAULT_ADMIN_ROLE) returns (string memory) {
        string memory masonryStatus;
        if (getTSHAREBalanceAtTombMasonry() > 0) {
            if (masonry.canWithdraw(address(this))) {
                masonry.withdraw(masonry.balanceOf(address(this)));
            } else {
                masonryStatus = "Masonry has balance but cannot withdraw just yet. Try again later.";
            }
        } else {
            masonryStatus = "No TSHAREs left in Masonry.";
        }
        tshare.safeTransfer(msg.sender, tshare.balanceOf(address(this)));
        return masonryStatus;
    }

    function withdrawLP() external onlyRole(DEFAULT_ADMIN_ROLE) {
        cemetery.withdraw(0, getLPBalanceAtTombCemetery());
        spookyTombFtmLP.transfer(msg.sender, spookyTombFtmLP.balanceOf(address(this)));
    }

    // Run the vanilla Tomb routine
    function runRoutine() external onlyRole(OPERATOR_ROLE) {
        _claimAnyTSHARERewardsFromCemetery();
        _claimAnyTOMBRewardsFromMasonryIfAllowed();

        _depositAnyTSHAREIntoMasonry();

        _takeProfit();
        _addLiquidity();
        _depositAnyLPIntoCemetery();
    }
}
