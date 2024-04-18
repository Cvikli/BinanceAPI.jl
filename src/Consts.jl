
const AUTOCANCEL_ORDER = 30
const MODE_SPOT    = Val(:SPOT)
const MODE_FUTURES = Val(:FUTURES)

const DEFAULT_MODE = Val(:FUTURES)



const CANDLE_MAP   = Dict(
	"1s"=>1, 
	"1m"=>60,     "3m"=>180,     "5m"=>300,    "10m"=>600,   "15m"=>900,   "30m"=>1_800, 
	"1h"=>3_600,  "2h"=>7_200,   "4h"=>14_400, "6h"=>21_600, "8h"=>28_800, "12h"=>43_200, 
	"1d"=>86_400, "3d"=>259_200, "1w"=>604_800)
const CANDLE_TO_MS = Dict(zip(keys(CANDLE_MAP), values(CANDLE_MAP) .* 1000))



const API_URL            = "https://api.binance.com/api/v3"		# URL of Binance API
const API_URL_FAPI       = "https://fapi.binance.com/fapi/v1"		# URL of Binance API
const API_URL_FAPI_v2    = "https://fapi.binance.com/fapi/v2"		# URL of Binance API
const API_URL_FUTURES    = "https://sapi.binance.com/sapi/v1/futures"		# URL of Binance API
const API_URL_FUTURES_V2 = "https://sapi.binance.com/sapi/v2/futures"		# URL of Binance API



const binance_futures_trades_default_hardcoded = "positionSide=BOTH&" * "workingType=CONTRACT_PRICE&" 



