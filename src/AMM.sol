// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./LiquidityPool.sol";

contract CoopySwapAMMManager {
    error PairAlreadyExistsError(string message, address existingLP);

    // Storage for existing pools
    mapping(address => mapping(address => address)) public existingPairs;

    function initializeLP(
        address token1,
        address token2
    ) public returns (address) {
        // Sort the addresses in a deterministic order before hashing
        // This is intended to prevent things like creating a USD/ETH pair when an ETH/USD pair already exists
        (address firstToken, address secondToken) = token1 < token2
            ? (token1, token2)
            : (token2, token1);

        // Hash the token addresses
        bytes memory pairBytes = abi.encode(firstToken, secondToken);
        bytes32 tokenPairHash = keccak256(pairBytes);

        // Check for an existing pair
        bool pairAlreadyExists = existingPairs[firstToken][secondToken] !=
            address(0);

        if (pairAlreadyExists) {
            revert PairAlreadyExistsError(
                "That liquidity pool already exists!",
                existingPairs[firstToken][secondToken]
            );
        }

        // Initialize LP and store its new address
        address newLP = address(
            new CoopySwapLiquidityPool{salt: tokenPairHash}(
                firstToken,
                secondToken
            )
        );

        existingPairs[firstToken][secondToken] = newLP;
        existingPairs[secondToken][firstToken] = newLP;

        return newLP;
    }
}
