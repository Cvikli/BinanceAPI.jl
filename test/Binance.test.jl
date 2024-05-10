using RelevanceStacktrace
using Revise
using Dates
using Boilerplate
using Boilerplate: @display
using BinanceAPI
using BinanceAPI: query_klines, timestamp, initialize_binance, marketdata2matrix, marketdata2ohlcvt



end_date = 1709650800 # - (1*365)*24*60*60
start_date = end_date - (1)    *24*60*60
start_date = 1715006942
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
# size(market_data[1])
@display unix2datetime(timestamp())
@display unix2datetime(timestamp()-60)
# @display unix2datetime(t[1]/1000), unix2datetime(t[end]/1000)
@display unix2datetime(start_date), unix2datetime(end_date)
#%%
using BinanceAPI: API_URL_FAPI
using HTTPUtils: GET
start_date = 1715165901001
end_date      = 1715166901000
body="symbol=$(market)&interval=1m&limit=1000" *
"&startTime=$(start_date)&endTime=$(end_date)"
GET(API_URL_FAPI * "/klines",    body, body_as_querystring=true)


#%%
start_date = 1715165901001
end_date      = 1715166901000
res=query_klines("BTCUSDT", "1m", start_date, end_date, Val(:SPOT)) 
#%%
#%%
market_data[1]
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


#%%
@code_warntype initialize_binance(apikey, secret, ["BTCUSDT"])
#%%
@typeof headers = ("X-MBX-APIKEY" => apikey)

header = headers
asdf = (;header= ("X-MBX-APIKEY" => apikey),secret)
@typeof asdf

#%%
#%%


using RelevanceStacktrace
using BinanceAPI: initialize_binance, process_futures_orders_ep_sl_tp
🦸abs_ep, 🦸abs_sl, 🦸abs_tp = 62000, 61000,64000
orders = [("BTCUSDT", :LONG, 0.001,🦸abs_ep, 🦸abs_sl, 🦸abs_tp)]
limiter = TokenBucketRateLimiter(tokens_per_second, max_tokens, initial_tokens)
apikey, secret = test_account
binance = initialize_binance(;apikey, secret, markets=["BTCUSDC", "BTCUSDT"])
@show "starting"
# process_futures_orders_ep_sl_tp(binance, orders)


#%%
using BinanceAPI: OPENORDERS_LIST

OPENORDERS_LIST(binance.access,"BTCUSDC")

#%%
using BinanceAPI: LISTEN_STREAM, live_futures_orders_ep_sl_tp, start_ep_sl_tp_strategy_listener, stop_ep_sl_tp_strategy_listener
using Boilerplate: @async_showerr



#%%
start_ep_sl_tp_strategy_listener(binance)
#%%
stop_ep_sl_tp_strategy_listener(binance)
#%%
using BinanceAPI: timestamp
using Printf
using RelevanceStacktrace
using Boilerplate
using HTTPUtils
market="BTCUSDC"
curr_price = parse(Float32,GET("https://api.binance.com/api/v3/ticker/price?symbol=$market").price)
@show curr_price
API_URL_FAPI       = "https://fapi.binance.com/fapi/v1"
amount=0.002
🦸abs_ep = curr_price-40 
@show 🦸abs_ep,curr_price
🦸abs_sl = 🦸abs_ep-20
🦸abs_tp = 🦸abs_ep+60
orders = [("BTCUSDC", :LONG, 0.01,125,🦸abs_ep, 🦸abs_sl, 🦸abs_tp)]
# process_futures_orders_ep_sl_tp(binance, orders)

live_futures_orders_ep_sl_tp(binance, orders)
#%%
parse(Float32,GET("https://api.binance.com/api/v3/ticker/price?symbol=$market").price)
#%%
curr_price = parse(Float32,GET("https://api.binance.com/api/v3/ticker/price?symbol=$market").price)
🦸abs_ep = curr_price+10 
🦸abs_sl = 🦸abs_ep+30
🦸abs_tp = 🦸abs_ep-90
@show 🦸abs_ep,curr_price
orders = [("BTCUSDC", :SHORT, -0.02,125,🦸abs_ep, 🦸abs_sl, 🦸abs_tp)]
live_futures_orders_ep_sl_tp(binance, orders)
#%%

using BinanceAPI: position_risks, error_handling, account_futures

resp = error_handling(position_risks, binance.access, [market])[market]

#%%
using BinanceAPI: get_maxtrade_amount
curr_price = parse(Float32,GET("https://api.binance.com/api/v3/ticker/price?symbol=$market").price)
v=get_maxtrade_amount(binance.access, market, 0.1, 125, curr_price)
v, v*curr_price
#%%

#%%
resp1 = error_handling(account_futures, binance.access)
push!(answ, resp1)
@display resp1
#%%
using JLD2
@save "answ.jld2" answ
#%%
answ
#%%
using DataStructures
kkks =  [ 
    :totalWalletBalance,  #W
    :totalMarginBalance,  #M
    :availableBalance,  # A
    :totalInitialMargin, #I
    :totalPositionInitialMargin,  #Ip
    :totalOpenOrderInitialMargin,  #Iop
    :totalUnrealizedProfit, # P
    :totalMaintMargin,  # MT
                # :totalCrossWalletBalance, 
                # :totalCrossUnPnl, 
                # :maxWithdrawAmount,
                 ]
using PrettyTables
qq=OrderedDict(k=>[parse.(Float64,a[k]) for a in answ] for (k) in kkks)
pretty_table(OrderedDict(k=>[a[k] for a in answ] for (k) in kkks), show_subheader=false)
#%%
answ[1][:feeTier]
#%%

qq
[(qq[:totalUnrealizedProfit][i],qq[:totalInitialMargin][i]) for i in 1:length(answ)]

#%%
using BinanceAPI: exchange_info, exchange_info_futures
filter(x->x["symbol"] in ["BTCUSDT"], exchange_info()["symbols"])
filter(x->x["symbol"] in ["BTCUSDT"], exchange_info_futures()["symbols"])
#%%
[(qq[:totalWalletBalance][i],qq[:totalMarginBalance][i]-qq[:totalUnrealizedProfit][i]) for i in 1:length(answ)]
#%%
[(qq[:availableBalance][i]+qq[:totalInitialMargin][i],qq[:totalWalletBalance][i]+qq[:totalUnrealizedProfit][i], qq[:totalMarginBalance][i]) for i in 1:length(answ)]
#%%
# [(qq[:availableBalance][i],qq[:totalWalletBalance][i]-qq[:totalInitialMargin][i]+qq[:totalUnrealizedProfit][i]) for i in 1:length(answ)]
#%%
[(qq[:totalMarginBalance][i],qq[:totalWalletBalance][i]+qq[:totalUnrealizedProfit][i]) for i in 1:length(answ)]
#%%
[(qq[:totalInitialMargin][i],qq[:totalPositionInitialMargin][i]+qq[:totalOpenOrderInitialMargin][i]) for i in 1:length(answ)]
#%%
[(qq[:totalMaintMargin][i]/qq[:totalPositionInitialMargin][i],) for i in 1:length(answ)]
#%%
[(qq[:totalMaintMargin][i]+qq[:totalPositionInitialMargin][i],) for i in 1:length(answ)]
#%%
Initial Margin = Notional Position Value / Leverage Level
Maintenance Margin = Notional Position Value * Maintenance Margin Rate - Maintenance Amount
#%%
answ = []
#%%


#%%
# 🦸abs_tp_trigger =  curr_price+38
@display POST(API_URL_FAPI * "/order",
																																		"symbol=$market&" *
																																		"type=LIMIT&" *
																																		"side=BUY&" *
																																		"positionSide=BOTH&" *
																																		"timeInForce=GTC&" *
																																		"workingType=CONTRACT_PRICE&" *
																																		# "reduceOnly=false&" *
																																		(market == "BTCUSDC" ? @sprintf("quantity=%.3f&", amount) : @sprintf("quantity=%.2f&", amount)) *
																																		(market == "BTCUSDC" ? @sprintf("price=%.1f&", 🦸abs_ep) : @sprintf("price=%.3f&", 🦸abs_ep)) *
																																		"timestamp=$(timestamp()*1000)" ,
																																		header=binance.access.header, secret=binance.access.secret, body_as_querystring=true, verbose=false)

# SL
@display POST(API_URL_FAPI * "/order",
"symbol=$market&" *
"type=STOP_MARKET&" *
"side=SELL&" *
"positionSide=BOTH&" *
"timeInForce=GTE_GTC&" *
"reduceOnly=true&" *
"workingType=CONTRACT_PRICE&" *
"priceProtect=true&" *
(market == "BTCUSDC" ? @sprintf("quantity=%.3f&", amount) : @sprintf("quantity=%.2f&", amount)) *
# (market == "BTCUSDC" ? @sprintf("price=%.1f&", 🦸abs_sl) : @sprintf("price=%.3f&", 🦸abs_sl)) *
(market == "BTCUSDC" ? @sprintf("stopPrice=%.1f&", 🦸abs_sl) : @sprintf("stopPrice=%.3f&", 🦸abs_sl)) *
"timestamp=$(timestamp()*1000)" ,
header=binance.access.header, secret=binance.access.secret, body_as_querystring=true, verbose=false)
# TP
@display POST(API_URL_FAPI * "/order",
"symbol=$market&" *
"type=TAKE_PROFIT&" *
"side=SELL&" *
"positionSide=BOTH&" *
"timeInForce=GTE_GTC&" *
"reduceOnly=true&" *
"workingType=CONTRACT_PRICE&" *
"priceProtect=true&" *
(market == "BTCUSDC" ? @sprintf("quantity=%.3f&", amount) : @sprintf("quantity=%.2f&", amount)) *
(market == "BTCUSDC" ? @sprintf("price=%.1f&", 🦸abs_tp) : @sprintf("price=%.3f&", 🦸abs_tp)) *
(market == "BTCUSDC" ? @sprintf("stopPrice=%.1f&", curr_price+0.1) : @sprintf("stopPrice=%.3f&", 🦸abs_tp)) *
"timestamp=$(timestamp()*1000)" ,
header=binance.access.header, secret=binance.access.secret, body_as_querystring=true, verbose=false)
#%%

curr_price = parse(Float32,GET("https://api.binance.com/api/v3/ticker/price?symbol=$market").price)
#%%

#%%
