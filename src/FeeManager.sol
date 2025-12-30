// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CoopySwapPoolFeeVault {
    uint256 cumulativeFeesPerLiquidityShare = 0;

    address immutable token1Address;
    address immutable token2Address;

    IERC20 immutable token1;
    IERC20 immutable token2;

    address immutable poolAddress;

    error Unauthorised();

    constructor(address firstTokenAddress, address secondTokenAddress) {
        poolAddress = msg.sender;

        token1Address = firstTokenAddress;
        token2Address = secondTokenAddress;

        token1 = IERC20(token1Address);
        token2 = IERC20(token2Address);
    }

    function withdrawFeeEntitlement(
        uint256 liquidityEntitlement,
        uint256 feeGrowthEntryPointFirstToken,
        uint256 feeGrowthEntryPointSecondToken,
        uint256 feeGrowthTrackerFirstToken,
        uint256 feeGrowthTrackerSecondToken,
        address userAddress
    ) external {
        if (msg.sender != poolAddress) {
            revert Unauthorised();
        }

        uint256 feesOwedToken1 = (feeGrowthTrackerFirstToken -
            feeGrowthEntryPointFirstToken) * liquidityEntitlement;
        uint256 feesOwedToken2 = (feeGrowthTrackerSecondToken -
            feeGrowthEntryPointSecondToken) * liquidityEntitlement;

        token1.transferFrom(address(this), userAddress, feesOwedToken1);
        token2.transferFrom(address(this), userAddress, feesOwedToken2);
    }
}
