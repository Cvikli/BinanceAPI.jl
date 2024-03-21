
using HTTP
download_split_ips(url) = split(String(HTTP.get(url).body),"\r\n")[1:end-1]
weshare_reformat(data) = begin 
	ip,port,user,pass = split(data,':')
	return "http://$user:$pass@$ip:$port"
end
parse_proxies(url) = weshare_reformat.(download_split_ips(url))

# url = "https://proxy.webshare.io/api/v2/proxy/list/download/itbhcjbtauygjeiemnavyakciuwljnmlclkfqjke/-/any/username/direct/-/"
# const ALL_PROXIES::Vector{String} = parse_proxies(url) # this way the package isn't precompileable!!
const ALL_PROXIES::Vector{String} = weshare_reformat.(include("proxylist.jl"))



