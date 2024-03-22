
using RateLimiter

const SAFE_ZONE = 1.4  # We limit the bandwidth... so we won't step over the limit! for sure... 30% safe zone...

# exchange_info()[:rateLimits]
#                              TokenBucketRateLimiter(token/sec,           max_token,       init_token)
const limit_request_weight   = TokenBucketRateLimiter(2400/60÷SAFE_ZONE,   2400÷SAFE_ZONE,  600)
const limit_raw_requests     = TokenBucketRateLimiter(61000/300÷SAFE_ZONE, 61000÷SAFE_ZONE, 10000)
const limit_orders_requests  = TokenBucketRateLimiter(100/10÷SAFE_ZONE,    100÷SAFE_ZONE,   10)

const lrw = limit_request_weight
const lor = limit_orders_requests

proxies_rate_limits::Vector{TokenBucketRateLimiter} = TokenBucketRateLimiter[deepcopy(lrw) for i in 1:length(ALL_PROXIES)]
prl                                                 = proxies_rate_limits

