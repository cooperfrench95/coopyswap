// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract CoopySwapLiquidityPool is ERC20Permit {
  address token1;
  address token2;

  uint8 token1Decimals = 18;
  uint8 token2Decimals = 18;

  uint256 token1Liquidity = 0;
  uint256 token2Liquidity = 0;

  uint8 constant SCALE_ZEROES = 18;
  uint8 constant MAX_SLIPPAGE_BPS = 200;
  uint8 constant SLIPPAGE_BPS_DENOMINATOR = 10_000;

  struct LiquidityPosition {
    uint256 token1Amount;
    uint256 token2Amount;
    date liquidityAdded;
    address owner;
  }

  mapping(address => LiquidityPosition) liquidityProviders;

  error InsufficientAllowance(string message);
  error BadInput(string message);
  error TokenUnsupported(string message, address token);
  error SlippageTooHigh();

  constructor (address firstToken, address secondToken) {
    token1 = firstToken;
    token2 = secondToken;

    token1Decimals = getDecimals(firstToken);
    token2Decimals = getDecimals(secondToken);
  }

  function provideLiquidity(uint256 firstTokenAmount, uint256 secondTokenAmount) {
    // Confirm allowance granted
    uint256 firstTokenAllowance = IERC20(token1).allowance(msg.sender, address(this));
    uint256 secondTokenAllowance = IERC20(token2).allowance(msg.sender, address(this));

    if (firstTokenAllowance < firstTokenAmount || secondTokenAllowance < secondTokenAmount) {
      revert InsufficientAllowance("You have not approved a sufficiently large allowance");
    }

    // Prevent adding wildly unbalanced liquidity if the pool is already established
    if (token1Liquidity > 0 || token2Liquidity > 0) {
      uint256 currentPrice = calcPrice(token1Liquidity, token2Liquidity);
      uint256 userAssumedPrice = calcPrice(firstTokenAmount, secondTokenAmount);
      
      uint256 slippage = Math.mulDiv(currentPrice, 10**SCALE_ZEROES, assumedPrice);

      if (slippage > MAX_SLIPPAGE_BPS) {
        revert SlippageTooHigh();
      }
    }
  }

  function calcSlippage(uint256 currentPrice, uint256 assumedPrice) {
    uint256 diff = currentPrice > assumedPrice ? currentPrice - assumedPrice : assumedPrice - currentPrice;

    // This does (diff * 10_000) / currentPrice
    Math.mulDiv(diff, SLIPPAGE_BPS_DENOMINATOR, currentPrice);
  }

  function getNormalizedInt(uint256 num, uint8 decimals) private returns (uint256) {
    if (decimals > SCALE_ZEROES) {
      return num * 10**(SCALE_ZEROES - decimals)
    }
    else if (decimals < SCALE_ZEROES) {
      return num / 10**(decimals - SCALE_ZEROES)
    }
    return num * 10**SCALE_ZEROES
  }

  function calcPrice(uint256 tokenALiquidity, uint256 tokenBLiqudity) {
    uint256 normalisedToken1Balance = getNormalizedInt(tokenALiquidity, token1Decimals)
    uint256 normalisedToken2Balance = getNormalizedInt(tokenBLiquidity, token2Decimals)

    return Math.mulDiv(normalisedToken1Balance, 10**(SCALE_ZEROES), normalisedToken2Balance)
  }

  function withdrawLiquidity() {

  }

  function swap() {

  }

  function getDecimals(address token) private view returns (uint8) {
    try IERC20Metadata(token).decimals() returns (uint8 d) {
        return d;
    } catch {
      revert TokenUnsupported("Token must implement decimals()", token);
    }
}
}
