using RelevanceStacktrace
using Revise
using Dates
using Boilerplate
using Boilerplate: @display
using BinanceAPI
using BinanceAPI: query_klines, timestamp, initialize_binance, marketdata2matrix, marketdata2ohlcvt



end_date = 1709650800 # - (1*365)*24*60*60
start_date = end_date - (1)    *24*60*60
# markets = ["ADA/BTC", "ETH/BTC", "BNB/BTC", "BTC/USDT", "ETH/USDT", "BNB/USDT", "ADA/BNB"];
# market = replace(markets[1], "/" => "")
market = "BTCUSDT";
market = "BTCUSDT";
# market_data = BinanceAPI.query_klines(market, "1h", start_date, end_date);
# market_data = BinanceAPI.query_klines(market, "5m", start_date, end_date);
market_data = BinanceAPI.query_klines(market, "1m", start_date, end_date);
o, h, l, c, v, t = marketdata2ohlcvt(market_data)

@sizes (market_data)
@sizes o, h, l, c, v, t
size(market_data[1])
@display unix2datetime(timestamp())
@display unix2datetime(timestamp()-60)
@display unix2datetime(t[1]/1000), unix2datetime(t[end]/1000)
@display unix2datetime(start_date), unix2datetime(end_date)
c[end]
#%%
@sizes (market_data[1])
@sizes (market_data[2])
#%%
using HTTP
proxy = "http://zcbjzpkw:2t82z7ri5l7s@154.95.36.199:6893"
response = HTTP.get("http://google.com", proxy=proxy)
#%%
using BinanceAPI: make_request_future 
@edit fetch(make_request_future("www.google.com"))
#%%
unix2datetime.(t./1000)
#%%
unix2datetime.((start_date, end_date))
#%%

end_date = 1709650800- (1*365)*24*60*60
#%%
market_data
#%%
using BinanceAPI: initialize_binance
include("./apikeys/binance_account_APIKEY_example.jl")
binance = initialize_binance(test_account, ["BTCUSDT"])

#%%
using BinanceAPI: get_maxtrade_amount

get_maxtrade_amount(binance.access, "BTCUSDT", 0.3, 72332.8984375)

#%%
using BinanceAPI: do_trade_limit
do_trade_limit(0.1, "BTCUSDT", a, 78300,test_account)

#%%
using RelevanceStacktrace
#%%
76737.95/1.05
#%%
0.001* 73300
#%%
using BinanceAPI: initialize_binance, apikey_secret2access
include("./apikeys/binance_account_APIKEY_example.jl")
binance = initialize_binance(apikey, secret, ["BTCUSDT"])
binance = initialize_binance(apikey_secret2access(apikey,secret), markets=["BNBUSDT"])


using BinanceAPI: process_orders, process_futures_orders_limit
process_futures_orders_limit(binance, [("BNBUSDT",0.45, 300.1)])

#%%
using Boilerplate
@sizes market_data
#%%
#%%
BTC_USDT_OHLCV_prices = marketdata2matrix(market_data)
@show (size(BTC_USDT_OHLCV_prices))
using JLD2
using FileIO
# @save "../data/BTC_USDT_OHLCV_prices_366-1825_5m.jld2" BTC_USDT_OHLCV_prices
# @save "../data/BTC_USDT_OHLCV_prices_366-1825_1h.jld2" BTC_USDT_OHLCV_prices
# @save "../data/BTC_USDT_OHLCV_prices_1-1825_1h.jld2" BTC_USDT_OHLCV_prices
# @save "../data/BTC_USDT_OHLCV_prices_1-1825_5m.jld2" BTC_USDT_OHLCV_prices
# @save "../data/BTC_USDT_OHLCV_prices_1-1095_5m.jld2" BTC_USDT_OHLCV_prices
# @save "../data/BTC_USDT_OHLCV_prices_1-1095_1h.jld2" BTC_USDT_OHLCV_prices
# @save "../data/BTC_USDT_OHLCV_prices_1095-1825_5m.jld2" BTC_USDT_OHLCV_prices
# @save "../data/BTC_USDT_OHLCV_prices_1095-1825_1h.jld2" BTC_USDT_OHLCV_prices
# @save "../data/BTC_USDT_OHLCV_prices_1-365_5m.jld2" BTC_USDT_OHLCV_prices
# @save "../data/BTC_USDT_OHLCV_prices_1-365_1h.jld2" BTC_USDT_OHLCV_prices
#%%
365*3
#%%
market_data[1][1]
#%%
moc_rest_req(x) = (println("stareted"); sleep(1.5); x)
@time moc_rest_req(1)
@show typeof(time())

#%%

using JET
res = report_package("BinanceAPI")
println(res)
#%%
using BinanceAPI: exchange_info
exinfo = exchange_info()[:rateLimits]
#%%
using BinanceAPI: all_open_orders, account, rate_limits
using Boilerplate
access = test_acc
@display rr = rate_limits(test_acc)
exchange_info()      
@display rr = rate_limits(test_acc)
rate_limits(access)
@display rr = rate_limits(test_acc)
all_open_orders(access)
@display rr = rate_limits(test_acc)
account(access)
@display rr = rate_limits(test_acc)

#%%
using BinanceAPI: rate_limits

rr = rate_limits(test_acc)
#%%
rr
#%%
exinfo[:rateLimits]
#%%
using BinanceAPI: cancel_all_open_orders
allopens=cancel_all_open_orders(binance.access)
#%%
# Place order:
# process_order(binance, [("BNBBTC",0.01,0.000911),
# 												("ETHBTC",-0.01,0.0365)])

#%%
using BinanceAPI: exchange_info
exinfo = exchange_info()

#%%

using BinanceAPI: potential_market_for_assets
assets = ["LTC", "BTC", "BNB", "ETH", "USDT", "TRX", "XRP", "DOGE", "XLM", "EOS", "HBAR", "XMR", "UNI", "AAVE",
 "MKR",  # High Volatility
 "SUSHI",  # Crazy Volument
 ]
market_list = potential_market_for_assets(assets)
println(assets, market_list)
@show length(assets), length(market_list)

#%%


using BinanceAPI: wsKlineStreams
# ts = wsKlineStreams(["ETHBTC","LTCBTC", "BNBBTC", "EOSETH", "BNBETH"], "1m")
ts = wsKlineStreams(["BTCUSDT"], "1h")




#%%
ts = timestamp()
market="BTCUSDT"
candletype="1h"
fetch("symbol=$(market)&interval=$(candletype)&limit=$(QUERY_LIMIT)&startTime=$(ts-1)500")
#%%

print_orders([("BNBBTC",0.01,0.000911),
							("ETHBTC",-0.01,0.0365),
							("ADABNB",-210.01,0.02365),
							("BTCUSDT",-0.0002,50231.0)])

							

#%%
using BinanceAPI: query_klines, timestamp, initialize_binance, balances


include("./apikeys/binance_account_APIKEY_example.jl")
@time initialize_binance(apikey, secret, ["BTCUSDT"])
;
#%%
@code_warntype initialize_binance(apikey, secret, ["BTCUSDT"])
#%%
@typeof headers = ("X-MBX-APIKEY" => apikey)

header = headers
asdf = (;header= ("X-MBX-APIKEY" => apikey),secret)
@typeof asdf

#%%
#%%
using RateLimiter

tokens_per_second = 20
max_tokens = 100
initial_tokens = 0

limiter = TokenBucketRateLimiter(tokens_per_second, max_tokens, initial_tokens)


function f_cheap()
	println("cheap")
	return 1
end

function f_costly()
	println("costly")
	return 2
end

result = 0

for i in 1:10
	result += @rate_limit limiter 1 f_cheap()
	result += @rate_limit limiter 10 f_costly()
end

println("RESULT: $result")


#%%

header = Dict("X-MBX-APIKEY" => apikey)
access = (;header, secret)

@code_warntype balances(access, x -> parse(Float64, x["free"]) > 0.0 || parse(Float64, x["locked"]) > 0.0)

#%%
@time balances(access, x -> parse(Float64, x["free"]) > 0.0 || parse(Float64, x["locked"]) > 0.0)

