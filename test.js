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

main()