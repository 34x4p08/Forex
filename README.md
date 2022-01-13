# Forex

Solidity contracts for stablecoin trading without or with minimal slippage. Powered by Curve, [SIP-120](https://sips.synthetix.io/sips/sip-120/) and Angle protocol.

## Why
The foreign exchange or forex market is the largest financial market in the world – larger even than the stock market, with a daily volume of $6.6 trillion, according to the 2019 Triennial Central Bank Survey of FX and OTC derivatives markets [(source)](https://www.investopedia.com/articles/forex/11/who-trades-forex-and-why.asp). 
Decentralized Forex is 10x better than centralized one, since it permissionless and limitless.

The mission of this project is to provide flexible and efficient way to exchange currencies with deep liquidity in 1 transaction.

### Notes 
- Currently, some currencies are disabled for atomic trading on Synthetix. Track available currencies via `atomicEquivalentForDexPricing(currencyKey)`: https://etherscan.io/address/0x6d9296Df2ad52F174bF671f555d78628bEBa7752#readContract

### Available paths
![Diagram](misc/diagram.drawio.png)

