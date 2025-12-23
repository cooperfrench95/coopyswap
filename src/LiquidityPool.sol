// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract CoopySwapLiquidityPool is ERC721Burnable {
    address token1;
    address token2;

    uint8 token1Decimals = 18;
    uint8 token2Decimals = 18;

    uint256 token1Liquidity = 0;
    uint256 token2Liquidity = 0;

    uint256 lastMintedID = 0;

    uint8 constant SCALE_ZEROES = 18;
    uint8 constant MAX_SLIPPAGE_BPS = 50;
    uint16 constant SLIPPAGE_BPS_DENOMINATOR = 10_000;

    uint256 K = 0;

    struct LiquidityPosition {
        uint256 token1Amount;
        uint256 token2Amount;
        uint256 liquidityAddedAt; // unix timestamp
        address owner;
    }

    mapping(uint256 => LiquidityPosition) liquidityProviders;

    error InsufficientAllowance(string message);
    error InsufficientBalance(string message);
    error BadInput(string message);
    error TokenUnsupported(string message, address token);
    error SlippageTooHigh();

    constructor(
        address firstToken,
        address secondToken
    ) ERC721("CoopySwapLiquidityTicket", "CPYSWP") {
        token1 = firstToken;
        token2 = secondToken;

        token1Decimals = getDecimals(firstToken);
        token2Decimals = getDecimals(secondToken);
    }

    function checkAllowance(
        IERC20 token,
        uint256 amountRequested,
        address user
    ) private view {
        uint256 allowance = token.allowance(user, address(this));

        if (allowance < amountRequested) {
            revert InsufficientAllowance(
                "You have not approved a sufficiently large allowance"
            );
        }
    }

    function checkBalance(
        IERC20 token,
        uint256 amountRequested,
        address user
    ) private view {
        uint256 balance = token.balanceOf(user);

        if (balance < amountRequested) {
            revert InsufficientBalance(
                "You do not have enough of those tokens to execute the transaction"
            );
        }
    }

    function performTransfer(
        address from,
        address to,
        IERC20 token,
        uint256 amount
    ) private {
        bool success = token.transferFrom(from, to, amount);
        require(success, "Token transfer failed");
    }

    function provideLiquidity(
        uint256 firstTokenAmount,
        uint256 secondTokenAmount
    ) public {
        if (firstTokenAmount == 0 || secondTokenAmount == 0) {
            revert BadInput("You can't provide zero liquidity");
        }

        IERC20 firstToken = IERC20(token1);
        IERC20 secondToken = IERC20(token2);

        // Confirm allowance granted
        checkAllowance(firstToken, firstTokenAmount, msg.sender);
        checkAllowance(secondToken, secondTokenAmount, msg.sender);

        // Confirm user has enough balance
        checkBalance(firstToken, firstTokenAmount, msg.sender);
        checkBalance(secondToken, secondTokenAmount, msg.sender);

        // Prevent adding wildly unbalanced liquidity if the pool is already established
        if (K > 0) {
            uint256 currentPrice = calcPrice(
                token1Liquidity,
                token2Liquidity,
                token1Decimals,
                token2Decimals
            );
            uint256 userAssumedPrice = calcPrice(
                firstTokenAmount,
                secondTokenAmount,
                token1Decimals,
                token2Decimals
            );

            uint256 slippage = calcSlippage(currentPrice, userAssumedPrice);

            if (slippage > MAX_SLIPPAGE_BPS) {
                revert SlippageTooHigh();
            }
        } else {
            K = firstTokenAmount * secondTokenAmount;
        }

        // Update internal balance trackers and receive actual liquidity
        token1Liquidity += firstTokenAmount;
        token2Liquidity += secondTokenAmount;
        performTransfer(
            msg.sender,
            address(this),
            firstToken,
            firstTokenAmount
        );
        performTransfer(
            msg.sender,
            address(this),
            secondToken,
            secondTokenAmount
        );

        // Mint liquidity NFT for the user. This will represent their share of the pool
        mintLiquidityNFT(firstTokenAmount, secondTokenAmount, msg.sender);
    }

    function mintLiquidityNFT(
        uint256 firstTokenAmount,
        uint256 secondTokenAmount,
        address to
    ) private {
        LiquidityPosition memory userPosition = LiquidityPosition({
            token1Amount: firstTokenAmount,
            token2Amount: secondTokenAmount,
            liquidityAddedAt: block.timestamp,
            owner: msg.sender
        });

        lastMintedID += 1;
        liquidityProviders[lastMintedID] = userPosition;

        _safeMint(to, lastMintedID);
    }

    function calcSlippage(
        uint256 currentPrice,
        uint256 assumedPrice
    ) private pure returns (uint256) {
        uint256 diff = currentPrice > assumedPrice
            ? currentPrice - assumedPrice
            : assumedPrice - currentPrice;

        // This does (diff * 10_000) / currentPrice
        return Math.mulDiv(diff, SLIPPAGE_BPS_DENOMINATOR, currentPrice);
    }

    function getNormalizedInt(
        uint256 num,
        uint8 decimals
    ) private pure returns (uint256) {
        if (decimals < SCALE_ZEROES) {
            return num * 10 ** (SCALE_ZEROES - decimals);
        } else if (decimals > SCALE_ZEROES) {
            return num / 10 ** (decimals - SCALE_ZEROES);
        }
        return num;
    }

    // Return the price of token A in terms of units of token B.
    function calcPrice(
        uint256 tokenALiquidity,
        uint256 tokenBLiquidity,
        uint8 tokenADecimals,
        uint8 tokenBDecimals
    ) private view returns (uint256) {
        uint256 normalisedToken1Balance = getNormalizedInt(
            tokenALiquidity,
            tokenADecimals
        );
        uint256 normalisedToken2Balance = getNormalizedInt(
            tokenBLiquidity,
            tokenBDecimals
        );

        // This does: (normalisedToken1Balance * 10**SCALE_ZEROES) / normalisedToken2Balance
        return
            Math.mulDiv(
                normalisedToken1Balance,
                10 ** (SCALE_ZEROES),
                normalisedToken2Balance
            );
    }

    function withdrawLiquidity(uint256 tokenId) public {
        // Look up the NFT metadata
        LiquidityPosition memory userLiquidityPosition = liquidityProviders[
            tokenId
        ];
        // Ensure user owns this NFT
        if (
            ownerOf(tokenId) != msg.sender ||
            userLiquidityPosition.owner != msg.sender
        ) {
            revert BadInput("That's not your NFT buddy");
        }

        // TODO: Figure out how much we owe the user in fees
        uint256 token1ReserveOwed = userLiquidityPosition.token1Amount;
        uint256 token2ReserveOwed = userLiquidityPosition.token2Amount;
        // Burn the NFT
        burn(tokenId);
        // Update our liquidity tracking
        token1Liquidity -= token1ReserveOwed;
        token2Liquidity -= token2ReserveOwed;
        // Remove the struct we have stored
        delete liquidityProviders[tokenId];

        // Transfer the tokens back to the user
        IERC20 firstToken = IERC20(token1);
        IERC20 secondToken = IERC20(token2);
        performTransfer(
            address(this),
            msg.sender,
            firstToken,
            token1ReserveOwed
        );
        performTransfer(
            address(this),
            msg.sender,
            secondToken,
            token1ReserveOwed
        );
    }

    function determineSwapDirection(
        address from,
        address to
    ) private returns (IERC20, IERC20, uint8, uint8, uint256, uint256) {
        IERC20 firstToken = IERC20(token1);
        IERC20 secondToken = IERC20(token2);

        // Check that two tokens are indeed the ones in this pool
        if (from == token1) {
            if (to != token2) {
                revert TokenUnsupported("Second token argument invalid", to);
            }
            return (
                firstToken,
                secondToken,
                token1Decimals,
                token2Decimals,
                token1Liquidity,
                token2Liquidity
            );
        } else if (from == token2) {
            if (to != token1) {
                revert TokenUnsupported("Second token argument invalid", to);
            }
            return (
                secondToken,
                firstToken,
                token2Decimals,
                token1Decimals,
                token2Liquidity,
                token1Liquidity
            );
        } else {
            revert TokenUnsupported(
                "That token is not part of this pool",
                from
            );
        }
    }

    function swap(address from, address to, uint256 amountDesired) public {
        (
            IERC20 fromToken,
            IERC20 toToken,
            uint8 fromTokenDecimals,
            uint8 toTokenDecimals,
            uint256 fromTokenLiquidity,
            uint256 toTokenLiquidity
        ) = determineSwapDirection(from, to);
        // Check that pool has enough of the token we want to swap
        checkBalance(toToken, amountDesired, address(this));
        require(
            fromTokenLiquidity > amountDesired,
            "Pool does not have enough of that token"
        );

        // Calculate the amount of fromToken we'll need from the user
        // Example: Pool has 2 ETH, 50 USDC
        // User wants to swap ETH for 25 USDC
        // They pass: from=ETH, to=USDC, amount=25
        // Price calculation: pool ETH liquidity / pool USDC liquidity = 2 / 50 = 0.04
        // Amount needed calculation: Price * amount requested = 25 * 0.04 = 1 ETH
        uint256 currentToTokenPrice = calcPrice(
            fromTokenLiquidity,
            toTokenLiquidity,
            fromTokenDecimals,
            toTokenDecimals
        );

        uint256 amountFromTokenRequired = amountDesired * currentToTokenPrice;

        // Check that user has allowed enough of their balance to be used
        checkAllowance(fromToken, amountFromTokenRequired, msg.sender);
        // Check that user has enough balance
        checkBalance(fromToken, amountFromTokenRequired, msg.sender);

        // Finally, sanity check that we are not drifting away from our K value
        uint256 fromTokenLiquidityAfterSwap = fromTokenLiquidity +
            amountFromTokenRequired;
        uint256 toTokenLiquidityAfterSwap = toTokenLiquidity - amountDesired;
        uint256 newK = fromTokenLiquidityAfterSwap * toTokenLiquidityAfterSwap;

        uint256 kDiff = newK > K ? newK - K : K - newK;
        if (
            Math.mulDiv(kDiff, SLIPPAGE_BPS_DENOMINATOR, K) > MAX_SLIPPAGE_BPS
        ) {
            revert SlippageTooHigh();
        }

        // Update liquidity
        if (from == token1) {
            token1Liquidity += amountFromTokenRequired;
            token2Liquidity -= amountDesired;
        } else {
            token2Liquidity += amountFromTokenRequired;
            token1Liquidity -= amountDesired;
        }

        // Execute swap
        performTransfer(
            msg.sender,
            address(this),
            fromToken,
            amountFromTokenRequired
        );
        performTransfer(address(this), msg.sender, toToken, amountDesired);
    }

    function getDecimals(address token) private view returns (uint8) {
        try IERC20Metadata(token).decimals() returns (uint8 d) {
            return d;
        } catch {
            revert TokenUnsupported("Token must implement decimals()", token);
        }
    }
}
