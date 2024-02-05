
using RateLimiter

# exchange_info()[:rateLimits]
#                        TokenBucketRateLimiter(token/sec, max_token,  init_token)
limit_request_weight   = TokenBucketRateLimiter(6000/60,   6000,       1000)
limit_raw_requests     = TokenBucketRateLimiter(61000/300, 61000,      10000)
limit_orders_requests  = TokenBucketRateLimiter(100/10,    100,        10)

lrw = limit_request_weight
lor = limit_orders_requests

