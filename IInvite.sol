// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

interface IInvite {
    // referring reward for different level
    function referReward(address _userAddr, uint256 _power) external;
    // redeem power for diffrent level
    function redeemPower(address _userAddr, uint256 _power) external;
}