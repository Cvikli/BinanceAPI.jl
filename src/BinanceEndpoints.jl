

using HTTPUtils: GET, PUT, POST, DELETE, s2j
using Printf

exchange_info()                            = @rate_limit lrw 20 GET(API_URL * "/exchangeInfo")
exchange_info_futures()         = @rate_limit lrw 20 GET(API_URL_FAPI * "/exchangeInfo")
rate_limits(access)     = @rate_limit lrw 40 GET(API_URL * "/rateLimit/order", "timestamp=$(timestamp()*1000)", header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
all_open_orders(access) = @rate_limit lrw 6  GET(API_URL * "/openOrders",      "timestamp=$(timestamp()*1000)", header=access.header, secret=access.secret, body_as_querystring=true, verbose=true)
account(access)         = @rate_limit lrw 10 GET(API_URL * "/account", "recvWindow=5000&timestamp=$(timestamp()*1000)", header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)


##### BUY / SELL
BUY(access, market, amount, price) = @rate_limit lor 2 POST(API_URL * "/order",
																														"symbol=$market&side=BUY&type=LIMIT&" *
																														# "timeInForce=IOC&" *
																														"timeInForce=GTC&" *
																														@sprintf("quantity=%.8f&price=%.8f&timestamp=%d", amount, price, timestamp()*1000), 
																														header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)

SELL(access, market, amount, price) = @rate_limit lor 2 POST(API_URL * "/order",
																														"symbol=$market&side=SELL&type=LIMIT&" *
																														# "timeInForce=IOC&" *
																														"timeInForce=GTC&" *
																														@sprintf("quantity=%.8f&price=%.8f&timestamp=%d", amount, price, timestamp()*1000), 
																														header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)

CANCEL(access, market, order_id)     = @rate_limit lor 1 DELETE(API_URL * "/order",
																					               @sprintf("symbol=%s&orderId=%d&timestamp=%d", market, order_id, timestamp()*1000), 
																					               header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
cancel_all_open_orders(access) = [CANCEL(access,order["symbol"],order["orderId"]) for order in all_open_orders(access)]


# FUTURES
balance_futures(access)       = @rate_limit lrw 10 GET(API_URL_FAPI_v2 * "/balance", "timestamp=$(timestamp()*1000)", header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
account_futures(access)       = @rate_limit lrw 20 GET(API_URL_FAPI_v2 * "/account", "timestamp=$(timestamp()*1000)", header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
position_risk_futures(access) = @rate_limit lrw 2  GET(API_URL_FAPI_v2 * "/positionRisk", "timestamp=$(timestamp()*1000)", header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
 
make_request(body::String)                 = @rate_limit lrw 10 GET(API_URL      * "/klines",    body, body_as_querystring=true)
make_request(body, proxy, plr)             = try; @rate_limit plr 10 GET(API_URL      * "/klines",    body, body_as_querystring=true; proxy=proxy)
catch e; isa(e, TimeoutException) ? make_request(body) : rethrow(e);end
make_request_tick(body::String)            = @rate_limit lrw 10 GET(API_URL      * "/aggTrades", body, body_as_querystring=true)
make_request_tick(body, proxy, plr)        = try; @rate_limit plr 10 GET(API_URL      * "/aggTrades", body, body_as_querystring=true; proxy=proxy)
catch e; isa(e, TimeoutException) ? make_request_tick(body) : rethrow(e);end
make_request_future(body::String)          = @rate_limit lrw 10 GET(API_URL_FAPI * "/klines",    body, body_as_querystring=true)
make_request_future(body, proxy, plr)      = try; @rate_limit plr 10 GET(API_URL_FAPI * "/klines",    body, body_as_querystring=true; proxy=proxy)
catch e;println((e,isa(e, TimeoutException),typeof(e))); isa(e, TimeoutException) ? make_request_future(body) : rethrow(e);end
make_request_tick_future(body::String)     = @rate_limit lrw 10 GET(API_URL_FAPI * "/aggTrades", body, body_as_querystring=true)
make_request_tick_future(body, proxy, plr) = try; @rate_limit plr 10 GET(API_URL_FAPI * "/aggTrades", body, body_as_querystring=true; proxy=proxy)
catch e; isa(e, TimeoutException) ? make_request_tick_future(body) : rethrow(e);end


# default futures trades
LEVERAGE(access, market, leverage)     = @rate_limit lor 1 POST(API_URL_FAPI * "/leverage",
																																																"symbol=$market&" *
																																																"leverage=$leverage&" *
																																																"timestamp=$(timestamp()*1000)" ,
																																																header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)

is_valid_trade(amount) = (amount >= 0.0005) # println(amount, " ", amount >= 0.0005); 
LONG_STOP_MARKET(access, market, amount, tprice) =  LONG_trigger(access, market, amount, tprice, "STOP_MARKET") 
LONG_TAKE_PROFIT(access, market, amount, price, tprice) =  LONG_limit_trigger(access, market, amount, price, tprice, "TAKE_PROFIT") 
LONG(access, market, amount
			)  = @rate_limit lor 2 POST(API_URL_FAPI * "/order",
																			"symbol=$market&" *
																			"type=MARKET&" *
																			"side=BUY&" *
																			"quantity=$amount&"*
																			binance_futures_trades_default_hardcoded *
																			"timestamp=$(timestamp()*1000)" ,
																			header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
LONG_limit(access, market, amount, price
							) = @rate_limit lor 2 POST(API_URL_FAPI * "/order",
																							"symbol=$market&" *
																							"type=LIMIT&" *
																							"side=BUY&" *
																							"timeInForce=GTC&" *
																							"quantity=$amount&"*
																							"price=$price&" *
																							binance_futures_trades_default_hardcoded *
																							"timestamp=$(timestamp()*1000)" ,
																							header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
LONG_trigger(      access, market, amount, tprice, type="MARKET"
								) = @rate_limit lor 2 POST(API_URL_FAPI * "/order",
																									"symbol=$market&" *
																									"type=$type&" *
																									"side=BUY&" *
																									"timeInForce=$(time_in_forcetype(type))&" *
																									"reduceOnly=$(reduceonly_type(type))&" *
																									"quantity=$amount&"*
																									"stopPrice=$tprice&" *
																									binance_futures_trades_default_hardcoded *
																									"timestamp=$(timestamp()*1000)" ,
																									header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
LONG_limit_trigger(access, market, amount, price, tprice, type="LIMIT"
												) = @rate_limit lor 2 POST(API_URL_FAPI * "/order",
																												"symbol=$market&" *
																												"type=$type&" *
																												"side=BUY&" *
																												"timeInForce=$(time_in_forcetype(type))&" *
																												"reduceOnly=$(reduceonly_type(type))&" *
																												# "timeInForce=GTE_GTC&" *
																												# "reduceOnly=true&" *
																												"quantity=$amount&"*
																												"price=$price&" *
																												"stopPrice=$tprice&" *
																												binance_futures_trades_default_hardcoded *
																												"timestamp=$(timestamp()*1000)" ,
																												header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
																																														

SHORT_STOP_MARKET(access, market, amount, tprice) =  SHORT_trigger(access, market, amount, tprice, "STOP_MARKET") 
SHORT_TAKE_PROFIT(access, market, amount, price, tprice) =  SHORT_limit_trigger(access, market, amount, price, tprice, "TAKE_PROFIT") 
SHORT(access, market, amount
				)  = @rate_limit lor 2 POST(API_URL_FAPI * "/order",
																				"symbol=$market&" *
																				"type=MARKET&" *
																				"side=SELL&" *
																				"quantity=$amount&"*
																				binance_futures_trades_default_hardcoded *
																				"timestamp=$(timestamp()*1000)" ,
																				header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
SHORT_limit(access, market, amount, price
								) = @rate_limit lor 2 POST(API_URL_FAPI * "/order",
																								"symbol=$market&" *
																								"type=LIMIT&" *
																								"side=SELL&" *
																								"timeInForce=GTC&" *
																								"quantity=$amount&"*
																								"price=$price&" *
																								binance_futures_trades_default_hardcoded *
																								"timestamp=$(timestamp()*1000)" ,
																								header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
SHORT_trigger(access, market, amount, tprice, type="MARKET"
									) = @rate_limit lor 2 POST(API_URL_FAPI * "/order",
																									"symbol=$market&" *
																									"type=$type&" *
																									"side=SELL&" *
																									"priceProtect=true&" *
																									"timeInForce=$(time_in_forcetype(type))&" *
																									"reduceOnly=$(reduceonly_type(type))&" *
																									"quantity=$amount&"*
																									"stopPrice=$tprice&" *
																									binance_futures_trades_default_hardcoded *
																									"timestamp=$(timestamp()*1000)" ,
																									header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
SHORT_limit_trigger(access, market, amount, price, tprice, type="LIMIT"
													 ) = @rate_limit lor 2 POST(API_URL_FAPI * "/order",
																													"symbol=$market&" *
																													"type=$type&" *
																													"side=SELL&" *
																													"priceProtect=true&" *
																													"timeInForce=$(time_in_forcetype(type))&" *
																													"reduceOnly=$(reduceonly_type(type))&" *
																													"quantity=$amount&"*
																													"price=$price&" *
																													"stopPrice=$tprice&" *
																													binance_futures_trades_default_hardcoded *
																													"timestamp=$(timestamp()*1000)" ,
																													header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)

time_in_forcetype(type) = type in ["MARKET","LIMIT","TAKE_PROFIT_LIMIT"] ? "GTC" : type in ["STOP_MARKET","TAKE_PROFIT"] ?  "GTE_GTC" : "UNKNOWN"
reduceonly_type(type)      = type in ["MARKET","LIMIT","TAKE_PROFIT_LIMIT"] ? false : type in ["STOP_MARKET","TAKE_PROFIT"] ?  true  : false
CANCEL(access, market) = @rate_limit lor 1 DELETE(API_URL_FAPI * "/allOpenOrders", "symbol=$market&timestamp=$(timestamp()*1000)", 
																									header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)

# /fapi/v1/countdownCancelAll

OPENORDERS_LIST(access, market) = @rate_limit lor 1 GET(API_URL_FAPI*"/openOrders",
																																			"symbol=$market&" *
																																			"timestamp=$(timestamp()*1000)",
																																			header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)



OPEN_STREAM(access) = POST(API_URL_FAPI * "/listenKey", "timestamp=$(timestamp()*1000)";header=access.header, body_as_querystring=true, verbose=true)
KEEP_ALIVE(access, listen_key) = PUT(API_URL_FAPI * "/listenKey", "listenKey=$(listen_key)", header=access.header, body_as_querystring=true, verbose=true)

LISTEN_USERSTREAM(access, callback) = LISTEN_STREAM(access, callback)
LISTEN_STREAM( exchange, callback) = begin
	exchange.epsltp_LIVE == true && return
	exchange.epsltp_LIVE=true
	
    listen_key = OPEN_STREAM(exchange.access)["listenKey"]
	# @show listen_key
    keep_alive = (timer) -> KEEP_ALIVE(exchange.access, listen_key)
    Timer(keep_alive, 1800; interval = 1800)

	repetition=0
	max_repetition=3
	while exchange.epsltp_LIVE
		try
			HTTP.WebSockets.open("wss://fstream.binance.com/ws/$(listen_key)") do io
				for data in io
					exchange.epsltp_LIVE==false && break
					rd = JSON3.read(data)
					@show rd
					callback(rd) && break
				end
			end
		catch e
			@show e
			if isa(e, EOFError)
				repetition+=1
				@info "EOFError!! We continue the RUN, but this is not nice!" # EOFError: read end of file
			elseif isa(e, ConnectError) && repetition < max_repetition
				repetition+=1
				@show "ConnectError!! We restart it! Repetition $repetition/$max_repetition."
			else
				showerror(stdout, e, catch_backtrace())

				rethrow(e)
			end
			sleep(1*sqrt(repetition+1))
		end
	end
	@info "STOPPED"
end

