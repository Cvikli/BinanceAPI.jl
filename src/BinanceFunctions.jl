# Binance API description: https://binance-docs.github.io/apidocs/spot/en/#general-info
# Implements the BinanceAPI and allows the use of its functionality through a BinanceExchange object

using .BinanceWorld: Exchange
using HTTP
using HTTP: WebSockets
using HTTP.Exceptions: ConnectError
using Printf
using Dates
using ProgressMeter
using Boilerplate: @async_showerr
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

request_all(url_bodies,p, fut_or_spot, proxylist=ALL_PROXIES) = if length(proxylist)==0
	asyncmap(body-> (next!(p);fetch(data_request(body, fut_or_spot))), url_bodies)
else
	PN = length(proxylist)
	asyncmap(i->(
		Pi = (i%PN)+1;
		next!(p);
		fetch(data_request(url_bodies[i], proxylist[Pi], prl[Pi],fut_or_spot))
	), 1:length(url_bodies); ntasks=PN)
end

request_all_tick(url_bodies,p, proxylist=ALL_PROXIES) = if length(proxylist)==0
	asyncmap(body::String -> (next!(p); process_tick2array(fetch(make_request_tick(body)))::Tuple{Vector{Int64}, Vector{Int64}, Vector{Float32}, Vector{Float32}}), url_bodies)
else
	PN = length(proxylist)
	asyncmap(i->(
		Pi = (i%PN)+1;
		next!(p);
		process_tick2array(fetch(make_request_tick(url_bodies[i], proxylist[Pi], prl[Pi])))
	), 1:length(url_bodies); ntasks=PN)
end

query_klines(markets::Vector{String}, candletype, from_time, to_time, mode=DEFAULT_MODE) = begin
	results = markets .|> m -> query_klines(m, candletype, from_time, to_time, mode)
	results = results .|> res_arr -> res_arr .|> fetch
	results = results .|> res_arr -> res_arr .|> parse_klines_all |> arr -> hcat(arr...)
end

query_klines(market::String, candletype, from_time, to_time, fut_or_spot=DEFAULT_MODE, QUERY_LIMIT=1000) = begin
	market = replace(market, "/" => "", "_" => "")
	duration_secs = CANDLE_MAP[candletype]
	query_duration_limit = duration_secs*QUERY_LIMIT * 1000 # get time duration that can be queried for the interval

	from_time *= (from_time > 10_000_000_000 ? 1 : 1000)
	to_time   *= (to_time   > 10_000_000_000 ? 1 : 1000)
	# (Binance works like: [from, to] instead of  ]from,to] that is why we need 1ms shift between the querries)
	start_end_times= [
		"&startTime=$(from_time)&endTime=$(min(from_time+query_duration_limit, to_time))";
		# ts+1 because we don't want to get the xxxxxxxx000 data twice: so we continue from the  xxxxxxxxx001 (from the next ms...) 
		["&startTime=$(ts)&endTime=$(min(ts+query_duration_limit, to_time))" for ts in from_time+query_duration_limit:query_duration_limit:to_time-1]
	]

	url_bodies = "symbol=$(market)&interval=$(candletype)&limit=$(QUERY_LIMIT)" .* start_end_times
	p = Progress(length(url_bodies); desc="Downloading:")
	data = request_all(url_bodies, p, fut_or_spot)
	# @show data
	return data
end

get_order_id(o) = o[1][:a]
get_first_n_end_id(market,from_time, to_time, isfutures) = begin
	body    = "symbol=$(market)&limit=1&startTime=$(from_time)"
	body_to = "symbol=$(market)&limit=1&startTime=$(to_time)"
	isfutures ? 
	(get_order_id(make_request_tick_future(body)), get_order_id(make_request_tick_future(body_to))) : 
	(get_order_id(make_request_tick(body)),        get_order_id(make_request_tick(body_to)))
end
query_ticks(market::String, isfutures, from_time, to_time, ) = begin
	market = replace(market, "/" => "", "_" => "")
	QUERY_LIMIT = 1000
	from_id, to_id = get_first_n_end_id(market, from_time, to_time, isfutures)
	@show from_id, to_id, to_id-from_id
	range = from_id:QUERY_LIMIT:to_id
	url_bodies= "symbol=$(market)&limit=$(QUERY_LIMIT)&fromId=" .* ["$(t_id)" for t_id in range]
	p = Progress(length(url_bodies))
	data_batched::Vector{Tuple{Vector{Int64}, Vector{Int64}, Vector{Float32}, Vector{Float32}}} = request_all_tick(url_bodies,p)
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


# function get_maxtrade_amount_new(accs, market, target_percent, current_price, leverage, gap=0.022)

# 	position_response = error_handling(position_risks, accs, [market])
# 	@show position_response
# 	if position_response === nothing
# 		println("No response from the positions: $position_response")
# 		return 0
# 	end
# 	account_response = error_handling(account_futures, accs)

# 	# remove :positions from the response dict:
# 	account_response = Dict(k=>v for (k,v) in account_response if k != :positions && k != :assets)
# 	@show account_response

# 	# If either response is missing, return 0 as we cannot proceed without this data.
# 	if account_response === nothing
# 		println("No response from the accounts: $account_response")
# 			return 0
# 	end

# 	# Extracting position and account details for the specified market.
# 	position_details = position_response[market]
# 	account_details = account_response

# 	# Parsing necessary values from the position and account details.
# 	current_position_amount = parse(Float64, position_details["positionAmt"])
# 	total_wallet_balance = parse(Float64, account_details[:totalWalletBalance])
# 	@show total_wallet_balance
	
# 	# Current invested amount in the market, considering leverage.
# 	current_invested_value = current_position_amount * parse(Float64, position_details["entryPrice"]) / parse(Float64, position_details["leverage"]) + parse(Float64, position_details["unRealizedProfit"])
# 	@show current_invested_value
# 	@show current_price

# 	# Calculating the total value of the portfolio, considering unrealized profits.
# 	total_portfolio_value = total_wallet_balance + parse(Float64, account_details[:totalUnrealizedProfit])
# 	@show total_portfolio_value

# 	# Determining the current percentage of the portfolio invested in the market.
# 	current_market_percentage = (current_invested_value / total_portfolio_value)
# 	@show current_market_percentage

# 	# Calculating the required change in investment to reach the target percentage.
# 	required_change_percentage = target_percent - current_market_percentage
# 	@show required_change_percentage

# 	# If the required change is minimal, we avoid making a trade to prevent unnecessary costs.
# 	if abs(required_change_percentage) < 0.02  # 2% threshold
# 			return 0
# 	end

# 	# Calculating the amount to adjust in the portfolio to achieve the target percentage.
# 	# This is the difference between the current and target investment values.
# 	required_change_in_value = required_change_percentage * total_portfolio_value

# 	# Adjusting the required change in value for slippage using the gap parameter and leveraging.
# 	adjusted_trade_value = (1 - gap) * required_change_in_value * leverage
# 	# @show adjusted_trade_value

# 	# Converting the value to the amount of the asset to trade, using the current market price.
# 	trade_amount = adjusted_trade_value / current_price
# 	# @show trade_amount

# 	return trade_amount
# end
get_maxtrade_amount(accs, market, percent, leverage, price, gap=0.01; noreduce=false) = begin
	local notional_trade_amount
	(balanc = error_handling(account_futures, accs))  === nothing && return 0
	total_balance = parse(Float64,balanc[:totalMarginBalance]) 
	percent *= (1-gap)
	if noreduce==false
		(pos_all = error_handling(position_risks, accs, [market]))  === nothing &&  return 0
		pos = pos_all[market]
		@show pos
		max_noti_value = parse(Float64,pos[:maxNotionalValue])
		ep = parse(Float64,pos[:entryPrice])
		summed_notional = parse(Float64,pos[:notional])  # leverage * totalPositionInitialMargin  (short negativ, long positive)
		avail_balance = parse(Float64,balanc[:availableBalance]) 
		@show percent*total_balance <=avail_balance , percent*total_balance, avail_balance
		notional_trade_amount = percent*total_balance * leverage - summed_notional
		notional_trade_amount >max_noti_value && @warn notional_trade_amount , max_noti_value, "this will result in error... and the problem is that on this leverage tier this is just too big trade size"

	else
		notional_trade_amount = percent*total_balance * leverage

	end
	return notional_trade_amount/price
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
			elseif resp["code"] == -2021 
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
																																															

do_trade(percentage, market, amount, exchange) =  begin
	amountstr = toprecision_amount(amount, market)
	if percentage >= 0.0e0
		@info ("LONG  $market $amount")
		resp = LONG(exchange.access, market, amountstr)
	else
		@info ("SHORT $market $amount")
		resp = SHORT(exchange.access, market, amountstr)
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

function process_futures_orders(exchange::Exchange, orders::Vector{Tuple{String, Float64, Float64}})
	for order in orders

		market, percentage, price = order
		amount = get_maxtrade_amount(exchange.access, market, percentage, price) #: get_maxtrade_amount(exchange.access, market, percentage, price)
		amount = amount - 0.001/2
		# amount = amount ÷ exchange.step_size[market] * exchange.step_size[market]
		amount < 0.002                             && continue
		# abs(amount) < exchange.min_qty[market]               && (@info "Amount is too low: $market $amount $price"; continue)
		# abs(amount) * price <= exchange.min_notional[market] && (@info "Too low volume: $market $(amount*price) value"; continue)
		# abs(price) < exchange.min_price[market]              && (@info "Price is too low: $market $amount $price"; continue)
		resp = error_handling(do_trade, percentage, market, amount, exchange)
		println("RESPONSE: $resp ")
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

futures_min_qty(market, price, binance) = max(
	binance.futures_min_qty[market],
	ceil((binance.futures_min_notional[market] / price), digits=binance.futures_quantity_precision[market])
  ) 

  futures_price_floor_w_tick_size(price, market, binance) =  begin
	acc = binance.futures_tick_size[market]
	value = sign(price)*floor(abs(price) / acc) * acc
	Printf.format(Printf.Format("%.$(round(Int,-log10(acc)))f" ), value)
end		
futures_qty_floor_w_step_size(qty, market, binance) =  begin
	acc = binance.futures_step_size[market]
	value = floor(abs(qty) / acc) * acc
	value, Printf.format(Printf.Format("%.$(round(Int,-log10(acc)))f" ), value)
end
									
function process_futures_orders_ep_sl_tp(exchange::Exchange, orders::Vector) 
	all_markets = unique([m for (m, amo, pri) in orders])
	for m in all_markets
		error_handling(CANCEL, exchange.access, m)
	end
	for order in orders

		market, 🔃, percentage, 🔥, 🦸abs_ep,🦸abs_sl,🦸abs_tp= order
		@show 🦸abs_ep

		side = 🔃 == :LONG
		@assert (percentage > 0 && 🔃 == :LONG) || (percentage < 0 && 🔃 == :SHORT)
		amount = get_maxtrade_amount(exchange.access, market, percentage, 🔥, 🦸abs_ep; noreduce=true) #: get_maxtrade_amount(exchange.access, market, percentage, price)
		amount, amountstr = futures_qty_floor_w_step_size(amount, market, exchange)
		amount< futures_min_qty(market, 🦸abs_ep, exchange)                             && continue
		🦸abs_epstr    = futures_price_floor_w_tick_size(🦸abs_ep, market, exchange)
		🦸abs_slstr    = futures_price_floor_w_tick_size(🦸abs_sl, market, exchange)
		🦸abs_tpstr    = futures_price_floor_w_tick_size(🦸abs_tp, market, exchange)
		ep_command = side ? LONG_limit : SHORT_limit
		sl_command = side ? SHORT_STOP_MARKET : LONG_STOP_MARKET
		tp_command = side ? SHORT_TAKE_PROFIT : LONG_TAKE_PROFIT
		resp=error_handling(    ep_command, exchange.access, market, amountstr, 🦸abs_epstr)
		println("RESPONSE: $resp ")
		resp=error_handling(    sl_command, exchange.access, market, amountstr, 🦸abs_slstr)
		println("RESPONSE: $resp ")
		try
			resp=error_handling(tp_command, exchange.access, market, amountstr, 🦸abs_tpstr,🦸abs_tpstr)
			println("RESPONSE: $resp ")
		catch e 
			showerror(stdout, e, catch_backtrace())
			println("WE WANT TO MANAGE THE IMMEDIATELY trigger error here!")
			rethrow(e)
		end
	end
end
			
start_ep_sl_tp_strategy_listener(exchange) = (@async_showerr LISTEN_STREAM(exchange, (data) ->process_ep_sl_tp(data, exchange)); println("EP/SL/TP strategy deployer is listening!"))
stop_ep_sl_tp_strategy_listener(exchange)   = exchange.epsltp_LIVE=false

process_ep_sl_tp(data, exchange) = begin

	if "e" in keys(data) && data["e"] == "ORDER_TRADE_UPDATE" 
		if "o" in keys(data) && "X" in keys(data["o"])  &&  "i" in keys(data["o"])
			order_id = data["o"]["i"]
			status = data["o"]["X"]
			if status == "FILLED"
				for (ep,sl,tp) in exchange.epsltp
					if order_id==ep["id"]
						market=ep["market"]
						amountstr=ep["amountstr"]
						sl_command=sl["command"]
						tp_command=tp["command"]
						@show order_id
						resp1=error_handling(sl_command, exchange.access, market, amountstr, sl["p_str"])
						println("RESPONSE: $resp1")
						sl["id"] = resp1["orderId"]
						resp2=error_handling(tp_command, exchange.access, market, amountstr, tp["p_str"],ep["p_str"])
						println("RESPONSE: $resp2 ")
						tp["id"] = resp2["orderId"]
						ep["status"] = "FILLED" # TODO remove
					end
				end
				filter!(x->x.ep["status"]=="FILLED", exchange.epsltp)
			end
		end
	end
	return false
end
ep_open(open_orders,price_str) = [order["orderId"] for order in  open_orders if price_str==order["price"]]
ep_open_strategy(epsltp,price_str) = [ep for (ep,sl,tp) in  epsltp if ep["p_str"]==price_str]
is_ep_open_strategy(epsltp,price_str) = !isempty(ep_open_strategy(epsltp,price_str))
is_sl_tp_same(epsltp,🦸abs_slstr, 🦸abs_tpstr) = any(sl["p_str"]==🦸abs_slstr && tp["p_str"]==🦸abs_tpstr for (ep,sl,tp) in  epsltp)
function live_futures_orders_ep_sl_tp(exchange::Exchange, orders::Vector) 
	# all_markets = unique([m for (m, amo, pri) in orders])
	# for m in all_markets
	# 	resp = error_handling(CANCEL, exchange.access, m)
	# 	println("RESPONSE: $resp ")
	# 	empty!(exchange.epsltp)
	# end

	
	for order in orders
		
		market, 🔃, percentage, 🔥, 🦸abs_ep,🦸abs_sl,🦸abs_tp= order

		side = 🔃 == :LONG
		@assert (percentage > 0 && 🔃 == :LONG) || (percentage < 0 && 🔃 == :SHORT)
		amount = get_maxtrade_amount(exchange.access, market, percentage, 🔥, 🦸abs_ep; noreduce=true) #: get_maxtrade_amount(exchange.access, market, percentage, price)
		amount, amountstr = futures_qty_floor_w_step_size(amount, market, exchange)
		amount< futures_min_qty(market, 🦸abs_ep, exchange)                             && continue
		🦸abs_epstr  = futures_price_floor_w_tick_size(🦸abs_ep, market, exchange)
		🦸abs_slstr  = futures_price_floor_w_tick_size(🦸abs_sl, market, exchange)
		🦸abs_tpstr  = futures_price_floor_w_tick_size(🦸abs_tp, market, exchange)
		ep_command = side ? LONG_limit : SHORT_limit
		sl_command = side ? SHORT_STOP_MARKET : LONG_STOP_MARKET
		tp_command = side ? SHORT_TAKE_PROFIT : LONG_TAKE_PROFIT

		@show ep_open_strategy(exchange.epsltp,🦸abs_epstr)
		if is_ep_open_strategy(exchange.epsltp,🦸abs_epstr)
			open_orders = OPENORDERS_LIST(exchange.access,market)
			@show ep_open(open_orders,🦸abs_epstr)
			if !isempty(ep_open(open_orders,🦸abs_epstr))
				@show  is_sl_tp_same(exchange.epsltp,🦸abs_slstr, 🦸abs_tpstr)
				if !is_sl_tp_same(exchange.epsltp,🦸abs_slstr, 🦸abs_tpstr)
					if !isempty(exchange.epsltp) 
						@show  "dfe"
						for (ep,sl,tp) in exchange.epsltp
							if ep["p_str"]==🦸abs_epstr
								sl["p_str"]=🦸abs_slstr
								tp["p_str"]=🦸abs_tpstr
							end
						end
					end
				end
			end
		else
			if !isempty(exchange.epsltp) 
				resp = error_handling(CANCEL, exchange.access, market)
				println("RESPONSE: $resp ")
				empty!(exchange.epsltp)
			end
			resp=error_handling(    ep_command, exchange.access, market, amountstr, 🦸abs_epstr)
			@show resp["orderId"]
			push!(exchange.epsltp,(;ep=Dict("market"=>market, "amountstr"=>amountstr,"p_str"=>🦸abs_epstr,"id"=>resp["orderId"],"status"=>"NEW"), sl=Dict("command"=>sl_command,"p_str"=>🦸abs_slstr), tp=Dict("command"=>tp_command,"p_str"=>🦸abs_tpstr)))
			
		end

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
	markets=replace.(markets, "_" => "")

	checked_symbols_futures::Vector{JSON3.Object} = filter(x->x["symbol"] in markets, exchange_info_futures()["symbols"])
	market_data_futures                                                                     = Dict{String,JSON3.Object}(x["symbol"] => x for x in checked_symbols_futures)
	checked_symbols::Vector{JSON3.Object} = filter(x->x["symbol"] in markets, exchange_info()["symbols"])
	market_data = Dict{String,JSON3.Object}(x["symbol"] => x for x in checked_symbols)
	# @show checked_symbols
	# @show market_data
	
	min_price = Dict{String,Float64}()
	min_qty = Dict{String,Float64}()
	min_notion = Dict{String,Float64}()
	tick_size = Dict{String,Float64}()
	step_size = Dict{String,Float64}()
	status = Dict{String,String}()
	# @show market_data
	for (m, data) in market_data
		PRICE_FILTER        = findfirst(v->v["filterType"]=="PRICE_FILTER",   data["filters"])
		LOT_SIZE                   = findfirst(v->v["filterType"]=="LOT_SIZE",       data["filters"])
		MARKET_LOT_SIZE = findfirst(v->v["filterType"]=="MARKET_LOT_SIZE",data["filters"])
		NOTIONAL                   = findfirst(v->v["filterType"]=="NOTIONAL",       data["filters"])
		@show data
		min_price[m] = parse(Float64, data["filters"][PRICE_FILTER]["minPrice"])
		tick_size[m] = parse(Float64, data["filters"][PRICE_FILTER]["tickSize"])
		min_notion[m] = parse(Float64, data["filters"][NOTIONAL]["minNotional"])
		min_qty[m]       = parse(Float64, data["filters"][LOT_SIZE]["minQty"])
		step_size[m] = parse(Float64, data["filters"][LOT_SIZE]["stepSize"])
		@show data["symbol"]
		@show data["filters"]
		status[m] = data["status"]
		@assert  status[m]=="TRADING" "$(status[m]) Be careful... we handle the TRADING pairs only in most case.. so you have to handle this case if you want"
	end
	
	futures_min_price = Dict{String,Float64}()
	futures_min_qty = Dict{String,Float64}()
	futures_min_notion = Dict{String,Float64}()
	futures_tick_size = Dict{String,Float64}()
	futures_step_size = Dict{String,Float64}()
	futures_quantity_precision = Dict{String,Int}()
	futures_price_precision = Dict{String,Int}()
	futures_liquidation_fee = Dict{String,Float64}()
	futures_status = Dict{String,String}()
	for (m, data) in market_data_futures
		PRICE_FILTER        = findfirst(v->v["filterType"]=="PRICE_FILTER",   data["filters"])
		LOT_SIZE                   = findfirst(v->v["filterType"]=="LOT_SIZE",       data["filters"])
		MARKET_LOT_SIZE = findfirst(v->v["filterType"]=="MARKET_LOT_SIZE",data["filters"])
		NOTIONAL                   = findfirst(v->v["filterType"]=="MIN_NOTIONAL",       data["filters"])
		@show data
		futures_min_price[m] = parse(Float64, data["filters"][PRICE_FILTER]["minPrice"])
		futures_tick_size[m] = parse(Float64, data["filters"][PRICE_FILTER]["tickSize"])
		futures_min_notion[m] = parse(Float64, data["filters"][NOTIONAL]["notional"])
		futures_min_qty[m]      = parse(Float64, data["filters"][LOT_SIZE]["minQty"])
		futures_step_size[m] = parse(Float64, data["filters"][LOT_SIZE]["stepSize"])
		futures_quantity_precision[m] = data["quantityPrecision"]
		futures_price_precision[m] = data["pricePrecision"]
		futures_liquidation_fee[m] = parse(Float64, data["liquidationFee"])
		futures_status[m] = data["status"]
		@assert  status[m]=="TRADING" "$(status[m]) Be careful... we handle the TRADING pairs only in most case.. so you have to handle this case if you want"
	end
	# for (m,_) in 
	# 	!(quote_order_qty[m] && spot_trading[m] && margin_trading[m] && status[m]=="TRADING") && 
	# 	@warn "$m status: $status quote_order_qty: $quote_order_qty spot_trading: $spot_trading margin_trading: $margin_trading"	
	# end
	bala = balances(access)
	binance = Exchange(name="Binance",
										 balance = bala,
										 markets =  markets,
										 min_qty = min_qty,
										 tick_size = tick_size,
										 step_size = step_size,
										 min_price = min_price,
										 min_notional = min_notion,
										 status = status,
										 futures_min_qty = futures_min_qty,
										 futures_tick_size = futures_tick_size,
										 futures_step_size = futures_step_size,
										 futures_min_price = futures_min_price,
										 futures_min_notional = futures_min_notion,
										 futures_quantity_precision = futures_quantity_precision,
										 futures_price_precision = futures_price_precision,
										 futures_liquidation_fee = futures_liquidation_fee,
										 futures_status = futures_status,
										 access=access,
										 epsltp=[],
										 epsltp_LIVE=false,
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

