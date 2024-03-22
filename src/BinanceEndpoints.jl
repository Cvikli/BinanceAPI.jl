

using HTTPUtils: GET, PUT, POST, DELETE, s2j
using Printf

exchange_info()         = @rate_limit lrw 20 GET(API_URL * "/exchangeInfo")
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


is_valid_trade(amount) = (amount >= 0.0005) # println(amount, " ", amount >= 0.0005); 
LONG(      access, market, amount)       = @rate_limit lor 2 POST(API_URL_FAPI * "/order",
																																"symbol=$market&" *
																																"type=MARKET&" *
																																"side=BUY&" *
																																(market == "BTCUSDT" ? @sprintf("quantity=%.3f&", amount) : @sprintf("quantity=%.2f&", amount)) *
																																"timestamp=$(timestamp()*1000)" ,
																																header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
LONG_limit(access, market, amount, price) = @rate_limit lor 2 POST(API_URL_FAPI * "/order",
																																	"symbol=$market&" *
																																	"type=LIMIT&" *
																																	"side=BUY&" *
																																	"timeInForce=GTC&" *
																																	(market == "BTCUSDT" ? @sprintf("quantity=%.3f&", amount) : @sprintf("quantity=%.2f&", amount)) *
																																	(market == "BTCUSDT" ? @sprintf("price=%.2f&", price) : @sprintf("price=%.3f&", price)) *
																																	"timestamp=$(timestamp()*1000)" ,
																																	header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
SHORT(      access, market, amount)       = @rate_limit lor 2 POST(API_URL_FAPI * "/order",
																																	 "symbol=$market&" *
																																	 "type=MARKET&" *
																																	 "side=SELL&" *
																																	 (market == "BTCUSDT" ? @sprintf("quantity=%.3f&", amount) : @sprintf("quantity=%.2f&", amount)) *
																																	 "timestamp=$(timestamp()*1000)" ,
																																	 header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)
SHORT_limit(access, market, amount, price) = @rate_limit lor 2 POST(API_URL_FAPI * "/order",
																																		"symbol=$market&" *
																																		"type=LIMIT&" *
																																		"side=SELL&" *
																																		"timeInForce=GTC&" *
																																		(market == "BTCUSDT" ? @sprintf("quantity=%.3f&", amount) : @sprintf("quantity=%.2f&", amount)) *
																																		(market == "BTCUSDT" ? @sprintf("price=%.2f&", price) : @sprintf("price=%.3f&", price)) *
																																		"timestamp=$(timestamp()*1000)" ,
																																		header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)


CANCEL(access, market) = @rate_limit lor 1 DELETE(API_URL_FAPI * "/allOpenOrders", "symbol=$market&timestamp=$(timestamp()*1000)", 
																									header=access.header, secret=access.secret, body_as_querystring=true, verbose=false)


# /fapi/v1/countdownCancelAll



KEEP_ALIVE(access, listenKey) = PUT(API_URL, "listenKey=$listenKey", header=access.header, body_as_querystring=true, verbose=true)