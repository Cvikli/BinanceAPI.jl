
using ProgressBars

getOPEN(d) = (parse(Float32,d[2]), parse(Float32,d[3]), parse(Float32,d[4]), parse(Float32,d[5]), parse(Float32,d[6]))
getKLINES(d)::Tuple{Float32,Float32,Float32,Float32,Float32, Int64} = (parse(Float32,d[2]), parse(Float32,d[3]), parse(Float32,d[4]), parse(Float32,d[5]), parse(Float32,d[6]), Int64(d[1]))
marketdata2matrix(market_data) = begin
	BTC_USDT_OHLCV_prices_raw = getOPEN.(market_data)
	BTC_USDT_OHLCV_prices = Matrix{Float32}(undef, length(BTC_USDT_OHLCV_prices_raw), 5)
	for (t,v) in enumerate(BTC_USDT_OHLCV_prices_raw)
		BTC_USDT_OHLCV_prices[t,:] .= v
	end
	BTC_USDT_OHLCV_prices
end
marketdata2ohlcvt(market_data) = begin
	sum_length = sum(length.(market_data))
	ts = Vector{Int64}(  undef, sum_length)
	o  = Vector{Float32}(undef, sum_length)
	h  = Vector{Float32}(undef, sum_length)
	l  = Vector{Float32}(undef, sum_length)
	c  = Vector{Float32}(undef, sum_length)
	v  = Vector{Float32}(undef, sum_length)
	j=1
	@inbounds for i in ProgressBar(1:length(market_data)::Int)
		# klines::Vector{Tuple{Float32,Float32,Float32,Float32,Float32, Int64}} = getKLINES.(market_data[i])
		length(market_data[i]) ==0 && continue
		raw::JSON3.Array{JSON3.Array, Base.CodeUnits{UInt8, String}, Vector{UInt64}} = market_data[i]
		leng = length(raw)
		for x in  1:leng
			row = raw[x]
			ts[j] = (row[1]::Int64)
			o[j]  = parse(Float32, row[2]::String)
			h[j]  = parse(Float32, row[3]::String) 
			l[j]  = parse(Float32, row[4]::String) 
			c[j]  = parse(Float32, row[5]::String) 
			v[j]  = parse(Float32, row[6]::String) 
			# BTC_USDT_OHLCV_prices[i,:] .= row[1:5]
			# BTC_USDT_OHLCV_time[i,1]    = row[end]
			j+=1	
		end
	end
	o, h, l, c, v, ts
end

init_data(data, market, steps; start_date, end_date=timestamp()) = init_data(data, market, steps, start_date, end_date)
init_data(data, market, steps, start_date, end_date) = begin
	market_data = query_klines(market, steps, start_date, end_date)
	o,h,l,c,v, ts = marketdata2ohlcvt(market_data)
	data.o    = [data.o; o] # OPEN
	data.h    = [data.h; h] # HIGH
	data.l    = [data.l; l] # LOW
	data.c    = [data.c; c] # CLOSE
	data.v    = [data.v; v] # VOLUME
	data.time = [data.time; ts]
	data
end



