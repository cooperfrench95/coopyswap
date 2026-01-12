// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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
        uint256 totalLiquidityPoints,
        address userAddress
    ) external {
        if (msg.sender != poolAddress) {
            revert Unauthorised();
        }

        uint256 feesOwedToken1 = Math.mulDiv(
            feeGrowthTrackerFirstToken - feeGrowthEntryPointFirstToken, liquidityEntitlement, totalLiquidityPoints
        );
        uint256 feesOwedToken2 = Math.mulDiv(
            feeGrowthTrackerSecondToken - feeGrowthEntryPointSecondToken, liquidityEntitlement, totalLiquidityPoints
        );

        bool success = token1.transfer(userAddress, feesOwedToken1);
        require(success, "Transfer failed");
        bool success2 = token2.transfer(userAddress, feesOwedToken2);
        require(success2, "Transfer failed");
    }
}
