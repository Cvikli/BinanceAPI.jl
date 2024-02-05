module Utils

mutable struct NoLimiter
end
(r::NoLimiter)(fn::Function, args...) = fn(args...)
execute(r::NoLimiter, fn::Function, args...) = fn(args...)

@kwdef mutable struct RateLimiter
	limit::Int=10
	duration::Int=1
	times::Vector{Float64}=[]
	safetyΔ::Float64=0.01   # to make sure we don't EXACTLY query at the limit
end

function get_waittime!(r::RateLimiter)
	waittime = 0.0
	if length(r.times) >= r.limit
		time_limith = popfirst!(r.times)
		waittime = max(0.0, r.duration + r.safetyΔ - (time() - time_limith))
	end
	push!(r.times, time() + waittime)
	return waittime
end

(r::RateLimiter)(fn::Function, args...) = begin
	waittime = get_waittime!(r)
	res = @async begin
		waittime>0 && sleep(waittime)
		fn(args...)
	end
end

function execute(r::RateLimiter, fn::Function, args...)
	waittime = get_waittime!(r)
	waittime>0 && sleep(waittime)
	return fn(args...)
end

end
