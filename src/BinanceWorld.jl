module BinanceWorld

export Exchange


@kwdef mutable struct Exchange
	name::String
	balance::Dict{String,NamedTuple}
	markets::Vector{String}
	muliplier_up::Dict{String,Float64}
	muliplier_down::Dict{String,Float64}
	min_notional::Dict{String,Float64}
	min_price::Dict{String,Float64}
	min_qty::Dict{String,Float64}
	tick_size::Dict{String,Float64}
	step_size::Dict{String,Float64}
	status::Dict{String,String}
	access::NamedTuple{(:header, :secret), Tuple{Dict{String, String}, String}}
	raw_market_data
end


end # module
