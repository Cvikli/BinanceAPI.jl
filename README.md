# BinanceAPI.jl
Clean Binance API

```julia
using BinanceAPI: exchange_info
exinfo = exchange_info()


using BinanceAPI: query_klines, timestamp
end_date = timestamp()- (1*365)*24*60*60
start_date = end_date - (3)    *24*60*60
market = "BTCUSDT";
market_data = query_klines(market, "5m", start_date, end_date);
o, h, l, c, v, ts = marketdata2ohlcvt(market_data)


using BinanceAPI: potential_market_for_assets
market_list = potential_market_for_assets(assets)
```

With Authority:
```julia
using BinanceAPI: initialize_binance, apikey_secret2access

include("./apikeys/binance_account_APIKEY_example.jl")

access = apikey_secret2access(apikey,secret)
initialize_binance(access, markets=["BNBUSDT"])

all_open_orders(access)
account(access)        
```

```julia
using BinanceAPI: BUY, SELL, CANCEL
market, amount, price = "BTC_USDT", 0.1, 42000
BUY(access, market, amount, price)
orderid = SELL(access, market, amount, price)
CANCEL(access, market, orderid)
cancel_all_open_orders(access)
```

```julia
using BinanceAPI: process_orders, process_futures_orders_limit
process_futures_orders_limit(binance, [("BNBUSDT",0.45, 300.1)]) # BUY 0.45 of the portfolio on 300.1 USDT / BNB. So no leverage yet. 
# This will be improved later on hopefully to be more clear...
```

This package can manage 
- streams
- ticks
- LONG limit + take profit & SHORT limit order + take profit (stop loss has to be handled manually)

But need time to document everything!

Also check out: BinanceEndpoints.jl

TODO:
- precision control... So we have to implement our precision control. 
- Dust trade protection
- Cleaning
- writing documentation
- as I check the code... THERE are numberous edge cases and also one or two hardcoded value yet due to this, that can be handled more universally. Also many standardization is still required. 

Any help is really appreciated to finish the library to be 100% perfect. :)


For me this is more clearer in spite of [Binance.jl](https://github.com/DennisRutjes/Binance.jl) is also very nice.
