using BinanceAPI: apikey_secret2access

apikey="..."
secret="..."
@assert apikey!="..." "You didn't specify the API key for you account"

test_account=apikey_secret2access(apikey,secret)
