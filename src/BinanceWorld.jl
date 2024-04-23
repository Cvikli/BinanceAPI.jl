module BinanceWorld

using Base: Event

export Exchange


@kwdef mutable struct Exchange
	name::String
	balance::Dict{String,NamedTuple}
	markets::Vector{String}
	min_notional::Dict{String,Float64}
	min_price::Dict{String,Float64}
	min_qty::Dict{String,Float64}
	tick_size::Dict{String,Float64}
	step_size::Dict{String,Float64}
	status::Dict{String,String}
	futures_price_precision::Dict{String,Int64}
	futures_quantity_precision::Dict{String,Int64}
	futures_min_notional::Dict{String,Float64}
	futures_min_price::Dict{String,Float64}
	futures_min_qty::Dict{String,Float64}
	futures_tick_size::Dict{String,Float64}
	futures_step_size::Dict{String,Float64}
	futures_liquidation_fee::Dict{String,Float64}
	futures_status::Dict{String,String}
	access::NamedTuple{(:header, :secret), Tuple{Dict{String, String}, String}}
	epsltp::Vector{NamedTuple{(:ep, :sl, :tp), Tuple{Dict,Dict,Dict}}} # ts, id, price, qty, market
	epsltp_LIVE::Bool
	newtrade::Event        = Event()
	raw_market_data
end


end # module
