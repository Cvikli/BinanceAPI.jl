



process_tick2array(v) = begin
	n = length(v)
	ids::Vector{Int}          = Vector{Int}(undef, n)
	ts::Vector{Int}           = Vector{Int}(undef, n)
	price::Vector{Float32}    = Vector{Float32}(undef, n)
	quantity::Vector{Float32} = Vector{Float32}(undef, n)

	j = process_tick2array!(v, 1, ids, ts, price, quantity)
	ids, ts, price, quantity
end
process_tick2array!(v, j, ids::Vector{Int}, ts::Vector{Int}, price::Vector{Float32}, quantity::Vector{Float32}) = begin
	n = length(v)
	for x in  1:n
		row = v[x]
		ids[j]      = row[:a]
		ts[j]       = row[:T]
		price[j]    = parse(Float64, row[:p])
		quantity[j] = parse(Float64, row[:q])
		j+=1	
	end
	@assert all((ids[2:end] .- ids[1:end-1]) .== 1) "Ids should be in order!"
	j
end



