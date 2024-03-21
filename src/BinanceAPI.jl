# Binance API description: https://binance-docs.github.io/apidocs/spot/en/#general-info
# Implements the BinanceAPI and allows the use of its functionality through a BinanceExchange object
module BinanceAPI
using Revise

include("Consts.jl")
include("BinanceWorld.jl")
include("Ticks.jl")
include("Proxies.jl")
include("BinanceRateLimits.jl")
include("BinanceEndpoints.jl")
include("BinanceFunctions.jl")
include("OHLCV.jl")

end # module BinanceAPI
