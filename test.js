const ETH_DECIMALS = 18
const USDC_DECIMALS = 6

const getNormalizedInt = (int, decimals) => {
  if (decimals < ETH_DECIMALS) {
    return int * 10 ** (ETH_DECIMALS - decimals)
  }
  else if (decimals > ETH_DECIMALS) {
    return int / 10 ** (decimals - ETH_DECIMALS)
  }
  return int
}

const toHumanNum = (int, decimals) => {
  return int / (10 ** decimals)
}

// Intended to help wrap my head around this integer math
function main() {
  const poolETH = 2 * 10 ** ETH_DECIMALS
  const poolUSDC = 50 * 10 ** USDC_DECIMALS
  console.log(poolETH, 'pool ETH')
  console.log(toHumanNum(poolETH, ETH_DECIMALS), 'pool ETH human format')
  console.log(poolUSDC, 'pool USDC')
  console.log(toHumanNum(poolUSDC, USDC_DECIMALS), 'pool USDC human format')

  const amountUSDCRequested = 25 * 10 ** USDC_DECIMALS
  const expectedETHPerUSDC = 1
  console.log(amountUSDCRequested, 'USDC requested')
  console.log(toHumanNum(amountUSDCRequested, USDC_DECIMALS), 'USDC requested human format')

  const normalisedPoolETH = getNormalizedInt(poolETH, ETH_DECIMALS)
  const normalisedPoolUSDC = getNormalizedInt(poolUSDC, USDC_DECIMALS)

  console.log(normalisedPoolETH, 'normalised pool ETH')
  console.log(normalisedPoolUSDC, 'normalised pool USDC')

  const priceInTermsOfETH = (normalisedPoolETH * 10 ** ETH_DECIMALS) / normalisedPoolUSDC;
  const priceInHumanFormat = toHumanNum(priceInTermsOfETH, ETH_DECIMALS)
  const ethPoolInHumanFormat = toHumanNum(poolETH, ETH_DECIMALS)

  console.log(priceInTermsOfETH, 'price in ETH for each USDC')
  console.log(priceInHumanFormat, 'price in ETH for each USDC in human format')

  const priceForRequestedUSDCInETH = amountUSDCRequested * priceInTermsOfETH
  const priceForAmountRequestedInHumanFormat = toHumanNum(priceForRequestedUSDCInETH, ETH_DECIMALS)
  console.log(priceForRequestedUSDCInETH, 'final price')
  console.log(priceForAmountRequestedInHumanFormat, 'final price human format') // Should be 1

  console.log(priceForRequestedUSDCInETH / amountUSDCRequested, 'price paid per USDC')
  console.log(toHumanNum(priceForRequestedUSDCInETH / amountUSDCRequested, ETH_DECIMALS), 'price paid per USDC human format')
}

// Scale up, do math, scale final answer back down
function calcFees() {
  const swapAmount = getNormalizedInt(1000 * 10 ** ETH_DECIMALS, ETH_DECIMALS)
  const fee_bps = getNormalizedInt(30, 0)
  const fee_denoninator = getNormalizedInt(10_000, 0)

  const timesAmount = Math.floor(fee_bps / fee_denoninator)

  console.log(`${swapAmount} * (${fee_bps} / ${fee_denoninator})`)
  console.log(`${swapAmount} * (${timesAmount})`)
  return toHumanNum(swapAmount * (fee_bps / fee_denoninator), ETH_DECIMALS)
}

const getLiquidityValue = (token1Amount, token2Amount, pool) => {
  if (pool.totalLiquidity === 0) {
    return Math.sqrt(token1Amount * token2Amount)
  }
  return Math.min((token1Amount * pool.totalLiquidity) / pool.token1Balance, (token2Amount * pool.totalLiquidity) / pool.token2Balance)
}

function deposit(token1Amount, token2Amount, pool) {
  const liquidity = getLiquidityValue(token1Amount, token2Amount, pool)
  pool.token1Balance += token1Amount
  pool.token2Balance += token2Amount
  const totalLiquidityEntry = pool.totalLiquidity
  pool.totalLiquidity += liquidity

  return { liquidity, totalLiquidityEntry }
}

function withdraw(originalPositionLiquidity, pool) {
  const liquidityEntitlement = originalPositionLiquidity.liquidity / pool.totalLiquidity
  const token1Amount = liquidityEntitlement * pool.token1Balance;
  const token2Amount = liquidityEntitlement * pool.token2Balance;

  pool.token1Balance -= token1Amount;
  pool.token2Balance -= token2Amount;
  pool.totalLiquidity -= originalPositionLiquidity.liquidity;

  return {
    token1Amount,
    token2Amount,
    liquidityEntitlement,
  }
}

function withdrawLiquidity() {
  const pool = {
    token1Balance: 0,
    token2Balance: 0,
    totalLiquidity: 0,
  }


  console.log(pool)
  const liquidityPosition = deposit(1, 50, pool)
  console.log(pool)
  const lp2 = deposit(2, 100, pool)
  console.log(pool)
  const withdrawResult = withdraw(liquidityPosition, pool);
  console.log(pool)
  const lp2Withdraw = withdraw(lp2, pool)
  console.log(pool)
  console.log(withdrawResult, lp2Withdraw, lp2)
  console.log(pool)
}

withdrawLiquidity()