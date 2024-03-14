# Binance API description: https://binance-docs.github.io/apidocs/spot/en/#general-info
# Implements the BinanceAPI and allows the use of its functionality through a BinanceExchange object

using .BinanceWorld: Exchange
using HTTP
using HTTP: WebSockets
using Printf
using Dates
using ProgressMeter
using Base.Threads
using JSON3
using Arithmetics: hcat_nospread



timestamp() = Int64(floor(time()))


get_stream_url(market_lowcase, timeframe) = get_stream_url(market_lowcase, timeframe, Val(:FUTURES))
get_stream_url(market_lowcase, timeframe, ::Val{:FUTURES}) = "wss://fstream.binance.com/stream?streams=$(market_lowcase)@kline_$timeframe"
get_stream_url(market_lowcase, timeframe, ::Val{:SPOT})    = "wss://stream.binance.com:9443/stream?streams=$(market_lowcase)@kline_$timeframe"


apikey_secret2access(apikey, secret) = (;header= Dict{String,String}("X-MBX-APIKEY" => apikey),secret)

potential_market_for_assets(assets, exinfo = nothing) = begin
	exinfo === nothing && (exinfo=exchange_info())
	potential_markets = String[]
	for market in exinfo["symbols"]
		quote_asset = String(market["quoteAsset"])
		base_asset  = String(market["baseAsset"])
		if base_asset in assets && quote_asset in assets  
			mar = market["symbol"]
			if !(market["status"] in ["BREAK", "HALT"]) || market["isMarginTradingAllowed"]==true
				push!(potential_markets, base_asset*"/"*quote_asset)
			else 
				println("Excluded: $(mar)")
			end
		end
	end
	return potential_markets
end

##### KLINES QUERY

parse_klines_all(res) = hcat_nospread(parse_klines.(res)::Vector{Vector{Float64}})
parse_klines(r) = Float64[ 
									parse(Float64,r[2]); # open price
									parse(Float64,r[3]); # high price
									parse(Float64,r[4]); # low price
									parse(Float64,r[5]); # close price
									parse(Float64,r[6]); # volume
									Float64(r[1])  # open time
									# Float32(r[9]) # number of trades
									]

query_klines(markets::Vector{String}, candletype, from_time, to_time, mode=DEFAULT_MODE) = begin
	results = markets .|> m -> query_klines(m, candletype, from_time, to_time, mode)
	results = results .|> res_arr -> res_arr .|> fetch
	results = results .|> res_arr -> res_arr .|> parse_klines_all |> arr -> hcat(arr...)
end

query_klines(market::String, candletype, from_time, to_time, ::Val{:FUTURES}=DEFAULT_MODE) = begin
	market = replace(market, "/" => "")
	QUERY_LIMIT, duration_secs = 1000, CANDLE_MAP[candletype]
	query_duration_limit = Second(duration_secs*QUERY_LIMIT).value # get time duration that can be queried for the interval
	if from_time < 10_000_000_000
		url_bodies="symbol=$(market)&interval=$(candletype)&limit=$(QUERY_LIMIT)&startTime=" .* ["$(ts-duration_secs+1)000&endTime=$(min(ts+query_duration_limit, to_time-duration_secs))000" for ts in from_time:query_duration_limit:to_time-duration_secs]
	else
		query_duration_limit *= 1000
		url_bodies="symbol=$(market)&interval=$(candletype)&limit=$(QUERY_LIMIT)&startTime=" .* ["$(ts)&endTime=$(min(ts+query_duration_limit, to_time))" for ts in from_time:query_duration_limit:to_time]
	end

	p = Progress(length(url_bodies))
	data = asyncmap(body-> (next!(p);fetch(make_request_future(body))), url_bodies)
	return data
end
query_klines(market::String, candletype, from_time, to_time, ::Val{:SPOT}) = begin
	market = replace(market, "/" => "")
	QUERY_LIMIT, duration_secs = 1000, CANDLE_MAP[candletype]
	query_duration_limit = Second(duration_secs*QUERY_LIMIT).value # get time duration that can be queried for the interval
	url_bodies="symbol=$(market)&interval=$(candletype)&limit=$(QUERY_LIMIT)&startTime=" .* ["$(ts-1)500&endTime=$(min(ts+query_duration_limit, to_time))499" for ts in from_time:query_duration_limit:to_time]
	p = Progress(length(url_bodies))
	data = asyncmap(body-> (next!(p);fetch(make_request(body))), url_bodies)
	return data
end

get_order_id(o) = o[1][:a]
get_first_n_end_id(market,from_time, to_time, isfutures) = begin
	body = "symbol=$(market)&limit=1&startTime=$(from_time*1000)"
	body_to = "symbol=$(market)&limit=1&startTime=$(to_time*1000)"
	!isfutures && get_order_id(make_request_tick(body)), get_order_id(make_request_tick(body_to))
	 isfutures && get_order_id(make_request_tick_future(body)), get_order_id(make_request_tick_future(body_to))
end
query_ticks(market::String, isfutures, from_time, to_time, ) = begin
	market = replace(market, "/" => "")
	QUERY_LIMIT = 1000
	from_id, to_id = get_first_n_end_id(market, from_time, to_time, isfutures)
	range = from_id:QUERY_LIMIT:to_id
	url_bodies= "symbol=$(market)&limit=$(QUERY_LIMIT)&fromId=" .* ["$(t_id)" for t_id in range]
	p = Progress(length(url_bodies))
	data_batched::Vector{Tuple{Vector{Int64}, Vector{Int64}, Vector{Float32}, Vector{Float32}}} = asyncmap(body::String -> (res::Tuple{Vector{Int64}, Vector{Int64}, Vector{Float32}, Vector{Float32}} = process_tick2array(fetch(make_request_tick(body))); next!(p); res), url_bodies)
	data = Tuple(vcat(getindex.(data_batched, i)...) for i in 1:4)
	# data = process_tick2arrays(data_batched)
	return data
end


function wsKlineStreams(symbols::Array, candletype="1m")
	allStreams = join(map(s -> "$(lowercase(s))@kline_$candletype", symbols), "/")
	@show allStreams
	url = "wss://stream.binance.com:9443/ws/$allStreams"
	@show url
	last_timestamp = 1_000_000_000_000
	HTTP.WebSockets.open(url; verbose=true) do io
		market_tss = Array{Int64,1}(undef,length(symbols))
		i=1
		while !eof(io)
			data = s2j(readavailable(io))
			# println(i, " ", last_timestamp, " ", data["k"]["t"])
			# callback(data)
			market_tss[i] = data["k"]["t"]
			i=(i%length(symbols)) + 1
			if (all(last_timestamp .!== market_tss) || last_timestamp == 1_000_000_000_000) 
				last_timestamp = data["k"]["t"]
				println("New tick! $(Dates.unix2datetime(last_timestamp/1000))")
			end
		end
	end
end


errdbug_msg(key,trade, resp) = begin
	@error "No '$key' message for trade order! ($trade)"
	@warn "RESPONSE: Try to find the mistake in the response\n $resp"
end
process_order_response_handler(access,resp, market, trade; verbose=false) = begin
	global AUTOCANCEL_ORDER
	if "status" in keys(resp)
		if resp["status"] == "NEW" 
			# println("$trade NEW")
		elseif resp["status"] == "PARTIALLY_FILLED" 
			println("$trade PARTIALLY_FILLED")
		elseif resp["status"] == "FILLED" && verbose
			println("$trade FILLED")
		elseif resp["status"] == "EXPIRED" 
			println("$trade  EXPIRED")
		elseif resp["status"] == "REJECTED" 
			println("$trade REJECTED")
		else
			errdbug_msg("status", trade, resp)
		end
	else
		errdbug_msg("status", trade, resp)
	end
	if "timeInForce" in keys(resp)
		if resp["timeInForce"] == "GTC" 
			@async (sleep(AUTOCANCEL_ORDER); cancel(access,market,resp["orderId"]))
		end
	else
		errdbug_msg("timeInForce", trade, resp)
	end
end
process_orders(exchange::Exchange, orders::Vector{Tuple{String, Float64, Float64}}) = begin
	for order in orders
		market, amount, price = order
		price = price ÷ exchange.tick_size[market] * exchange.tick_size[market]
		amount = amount ÷ exchange.step_size[market] * exchange.step_size[market]
		if abs(amount) < exchange.min_qty[market]
			@info "Amount is too low: $market $amount $price"
			continue
		end
		if abs(amount) * price <= exchange.min_notional[market]
			@info "Too low volume: $market $(amount*price) value"
			continue
		end
		if abs(price) < exchange.min_price[market]
			@info "Price is too low: $market $amount $price"
			continue
		end
		if amount >= 0.0e0
			# price=round(1.0001*price, digits=7)
			println("BUY  $market $amount $price")
			resp = buy(exchange.access, market, amount, price)
		else
			# price=round(0.9999*price, digits=7)
			println("SELL $market $amount $price")
			resp = sell(exchange.access, market, -amount, price)
		end
		
		# println("RESPONSE: $resp ")
		process_order_response_handler(exchange.access,resp, market, "$market $amount $price ", verbose = true)	end
end


get_maxtrade_amount(accs, market, percent, price, gap=0.022) = begin
	resp = error_handling(position_risks, accs, [market])
	if resp === nothing
		return 0
	else
		pos = resp[market]
		# @show pos
		resp1 = error_handling(account_futures, accs)
		if resp1 === nothing
			return 0
		else
			balanc = resp1		
			# @show keys(balanc)
			@show balanc[:availableBalance]
			# display( Dict(k=>v for (k,v) in (balanc) if !(k in [:positions, :assets])))
			tot_margin_balance = parse(Float64,balanc[:totalMarginBalance]) 
			tot_margin_init_balance = parse(Float64,balanc[:totalPositionInitialMargin]) 
			pos_amount = parse(Float64,pos["positionAmt"])
			mark_price = price
			@show pos_amount
			@show percent
			# @show mark_price
			is_short_nothing_long = (pos_amount > 0.01 ? 1 : pos_amount < -0.01 ? -1 : 0)
			to_short_nothing_long = (percent > 0.01    ? 1 : percent < -0.01    ? -1 : 0)
			todo = abs(to_short_nothing_long - is_short_nothing_long)
			amount = todo >1.4 ? tot_margin_init_balance+tot_margin_balance : todo >0.6 ? tot_margin_balance : 0
			return (1 - gap) * (amount ) * parse(Float64,pos["leverage"]) / mark_price
			end
	end
	# display(Dict((bk => b) for (bk,b) in balanc if !(bk in [:assets, ])))
	# @show keys(balanc)
end

error_handling(fn, args...) = begin
	repeated = 0
	try
		return fn(args...)
	catch e
		if isa(e, HTTP.Exceptions.StatusError)
			resp=JSON3.read(e.response.body)
			if resp["code"] == -2019 
				@error resp["msg"] * "\n" * "$fn($((args...,))" # 
				@info ("We continue the RUN, but this is not nice!")# EOFError: read end of file
			elseif resp["code"] == -2015 
				showerror(stdout, e, catch_backtrace())
				@error resp["msg"]  * "\n" * "$fn($((args...,))" # "Invalid API-key, IP, or permissions for action."
				rethrow(e)
			elseif resp["code"] == -1021  "Timestamp for this request is outside of the recvWindow."
				@error resp["msg"] * "\n" * "$fn($((args...,))"
				if repeated == 0
					return fn(args...)
				end
				repeated += 1
			elseif resp["code"] == 418 
				@error resp["msg"] * "\n" * "WE ARE BANNED SHIT... Waiting for unbann..." * "\n" * "$fn($((args...,))"
			elseif resp["code"] == -1001 
				# "code":-1001,"msg":"Internal error; unable to process your request. Please try agai
				@error resp["msg"] * "\n" * "Why is this happening???" * "\n" * "$fn($((args...,))"
			elseif resp["code"] == -4003
				@error resp["msg"] * "\n" * "This can happen due to the min step size just cutted your value to zero in the end when created the request or you sent zero qty ineed..." * "\n" * "$fn($((args...,))"
			elseif resp["code"] == -4016 
				@error resp["msg"] * "\n" * "$fn($((args...,))" # "Limit price can't be higher than 76737.97" ...
			elseif resp["code"] == -4164 
				@error resp["msg"] * ".... so Price * Quantity >= Notional (unless reduce only)" * "\n" * "$fn($((args...,))"
			elseif resp["code"] == -5028 
				# {"code":-5028,"msg":"Timestamp for this request is outside of the ME recvWindow."}""")
				@error resp["msg"] * "\n" * "Why is this happening???"
			else
				showerror(stdout, e, catch_backtrace())
				rethrow(e)
			end
		else
			showerror(stdout, e, catch_backtrace())
			rethrow(e)
		end
	end
	return nothing
end

do_trade(percentage, market, amount, price, exchange) =  begin
	if percentage >= 0.0e0
		@info ("LONG  $market $amount $price")
		resp = LONG(exchange.access, market, amount)
	else
		@info ("SHORT $market $amount $price")
		resp = SHORT(exchange.access, market, amount)
	end
	return resp
end

do_trade_limit(percentage, market, amount, price, exch::Exchange) = do_trade_limit(percentage, market, amount, price, exch.access)
do_trade_limit(percentage, market, amount, price, access) =  begin
	if percentage >= 0.0e0
		@info ("LONG  $market $amount $price")
		resp = error_handling(LONG_limit, access, market, amount, price)
	else
		@info ("SHORT $market $amount $price")
		resp = error_handling(SHORT_limit, access, market, amount, price)
	end
	return resp
end

function process_futures_orders(exchange::Exchange, orders::Vector{Tuple{String, Float64}})
	for order in orders

		market, percentage = order
		@assert false "why didn't we have the price varialbe here... :D"
		price = 1000f0
		amount = percentage >= 0 ? get_maxtrade_amount(exchange.access, market, percentage, price) : get_maxtrade_amount(exchange.access, market, percentage, price)
		amount = amount - 0.001/2
		# amount = amount ÷ exchange.step_size[market] * exchange.step_size[market]
		amount < 0.002                             && continue
		# abs(amount) < exchange.min_qty[market]               && (@info "Amount is too low: $market $amount $price"; continue)
		# abs(amount) * price <= exchange.min_notional[market] && (@info "Too low volume: $market $(amount*price) value"; continue)
		# abs(price) < exchange.min_price[market]              && (@info "Price is too low: $market $amount $price"; continue)
		resp = error_handling(do_trade, percentage, market, amount, exchange)
	end
end
function process_futures_orders_limit(exchange::Exchange, orders::Vector{Tuple{String, Float64, Float64}})
	all_markets = unique([m for (m, amo, pri) in orders])
	for m in all_markets
		error_handling(CANCEL, exchange.access, m)
	end
	for order in orders

		market, percentage, price = order

		side = percentage >= 0
		amount = get_maxtrade_amount(exchange.access, market, percentage, price) #: get_maxtrade_amount(exchange.access, market, percentage, price)
		amount = amount - 0.001/2
		amount < 0.002                             && continue


		resp = error_handling(do_trade_limit, percentage, market, amount, price, exchange)
		println("RESPONSE: $resp ")
	end
end

##### ACCOUNT_FUTURES
leverages(access) = Dict(poss["symbol"] => parse(Int64, poss["leverage"]) for poss in account_futures(access)["position"])
position_risks_all(access)   = Dict(poss["symbol"] => poss for poss in position_risk_futures(access))
position_risks(access, filt) = Dict(poss["symbol"] => poss for poss in position_risk_futures(access) if poss["symbol"] in filt)
position_risks(access)       = Dict(poss["symbol"] => poss for poss in position_risk_futures(access) if poss["symbol"] in ["BTCUSDT", "BTCBUSD"])

##### BALANCE_FUTURES
balances_futures_NOZERO(exch::Exchange) = balances_futures_NOZERO(exch.access)
balances_futures_NOZERO(access)         = Dict(asset_d["asset"] => parse(Float64, asset_d["crossWalletBalance"]) for asset_d in balance_futures(access) if parse(Float64, asset_d["crossWalletBalance"]) > 0)
balances_futures(exch::Exchange; filt)  = balances_futures(exch.access; filt) 
balances_futures(access; filt)          = Dict(asset_d["asset"] => parse(Float64, asset_d["crossWalletBalance"]) for asset_d in balance_futures(access) if asset_d["asset"] in filt)


##### BALANCE
balances(exchange::Exchange) = balances(exchange.access)
balances(access::NamedTuple{(:header, :secret), Tuple{Dict{String, String}, String}}; balanceFilter = x -> parse(Float64, x["free"]) > 0.0 || parse(Float64, x["locked"]) > 0.0) = balances(access, balanceFilter)
balances(access::NamedTuple{(:header, :secret), Tuple{Dict{String, String}, String}}, balanceFilter) = begin
	resp = error_handling(account,access)# balance_timestamp = time()
	balances = filter(balanceFilter, resp["balances"])
	# @show balances
	Dict{String, NamedTuple{(:FREE, :LOCKED), Tuple{Float64, Float64}}}(b["asset"]::String => (FREE=parse(Float64, b["free"]), LOCKED=parse(Float64, b["locked"])) for b in balances)
end
# balances(apikey, secret; balanceFilter = x -> parse(Float64, x["free"]) > 0.0 || parse(Float64, x["locked"]) > 0.0) = balances(apikey, secret, balanceFilter)
# balances(apikey, secret, balanceFilter) = begin
# 	header = ("X-MBX-APIKEY" => apikey)
# 	balances((;header,secret); balanceFilter=balanceFilter)
# end

##### BINANCE CREATE (Info, Balance...)
initialize_binance_withaccess(;access, markets) = initialize_binance(access, markets)
initialize_binance(;apikey, secret, markets) = initialize_binance_withaccess(access=apikey_secret2access(apikey, secret); markets)
initialize_binance(access, markets) = begin

	checked_symbols::Vector{JSON3.Object} = filter(x->x["symbol"] in markets, exchange_info()["symbols"])
	market_data = Dict{String,JSON3.Object}(x["symbol"] => x for x in checked_symbols)
	@show checked_symbols
	@show market_data
	
	min_price = Dict{String,Float64}()
	tick_size = Dict{String,Float64}()
	bid_muliplier_up = Dict{String,Float64}()
	bid_muliplier_down = Dict{String,Float64}()
	ask_muliplier_up = Dict{String,Float64}()
	ask_muliplier_down = Dict{String,Float64}()
	min_qty = Dict{String,Float64}()
	step_size = Dict{String,Float64}()
	min_notion = Dict{String,Float64}()
	quote_order_qty = Dict{String,Bool}()
	spot_trading = Dict{String,Bool}()
	margin_trading = Dict{String,Bool}()
	status = Dict{String,String}()
	# @show market_data
	for (m, data) in market_data
		PRICE_FILTER    = findfirst(v->v["filterType"]=="PRICE_FILTER",   data["filters"])
		LOT_SIZE        = findfirst(v->v["filterType"]=="LOT_SIZE",       data["filters"])
		MARKET_LOT_SIZE = findfirst(v->v["filterType"]=="MARKET_LOT_SIZE",data["filters"])
		NOTIONAL        = findfirst(v->v["filterType"]=="NOTIONAL",       data["filters"])
	# 	# @show data
		min_price[m] = parse(Float64, data["filters"][PRICE_FILTER]["minPrice"])
		tick_size[m] = parse(Float64, data["filters"][PRICE_FILTER]["tickSize"])
		min_qty[m]   = parse(Float64, data["filters"][LOT_SIZE]["minQty"])
		step_size[m] = parse(Float64, data["filters"][LOT_SIZE]["stepSize"])
	# 	# bid_muliplier_up[m] = parse(Float64, data["filters"][7]["bidMultiplierUp"])
	# 	# bid_muliplier_down[m] = parse(Float64, data["filters"][7]["bidMultiplierDown"])
	# 	# ask_muliplier_up[m] = parse(Float64, data["filters"][7]["bidMultiplierUp"])
	# 	# ask_muliplier_down[m] = parse(Float64, data["filters"][7]["bidMultiplierDown"])
		@show data
		@show data["filters"]
		min_notion[m] = parse(Float64, data["filters"][NOTIONAL]["minNotional"])
	# 	quote_order_qty[m] = data["quoteOrderQtyMarketAllowed"]
	# 	spot_trading[m] = data["isSpotTradingAllowed"]
	# 	margin_trading[m] = data["isMarginTradingAllowed"]
	# 	status[m] = data["status"]
	end
	# for (m,_) in 
	# 	!(quote_order_qty[m] && spot_trading[m] && margin_trading[m] && status[m]=="TRADING") && 
	# 	@warn "$m status: $status quote_order_qty: $quote_order_qty spot_trading: $spot_trading margin_trading: $margin_trading"	
	# end
	bala = balances(access)
	binance = Exchange(name="Binance",
										 balance = bala,
										 markets =  replace.(markets, "_" => ""),
										 min_qty = min_qty,
										 tick_size = tick_size,
										 step_size = step_size,
										 min_price = min_price,
										 min_notional = min_notion,
										 muliplier_up = bid_muliplier_up,
										 muliplier_down = bid_muliplier_down,
										 status = status,
										 access=access,
										#  raw_=
										 raw_market_data=nothing)
	return binance
end


###### ACCESSORIES
print_orders(orders) = begin 
	@printf "%8s  | %9s   |%10s\n" "MARKET" "AMOUNT" "PRICE"
	for order in orders 
		@printf "%9s | %+11.8g |%14.8f \n" order[1] order[2] order[3]
	end
end

