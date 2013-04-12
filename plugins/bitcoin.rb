# 
# by brian ploch <brian -at- ploch.net> 2013-04-10
#
# retrive bitcoin exchange values from mtgox.com
#
#
# Version 0.1
#  Initial script to pull USD only
#
# 0.2
#   Add multi-currency support
#

require 'json'
require 'net/http'
require 'uri'

class BitcoinPricePlugin < Plugin

	def initialize
		super
		@user_agent = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_3; en-us) AppleWebKit/533.16 (KHTML, like Gecko) Version/5.0 Safari/533.16"
    @currency_list = {  "USD" => "US Dollar",
                        "GBP" => "Great British Pound",
                        "EUR" => "Euro",
                        "JPY" => "Japanese Yen",
                        "AUD" => "Australian Dollar",
                        "CAD" => "Canadian Dollar",
                        "CHF" => "Swiss Franc",
                        "CNY" => "Chinese Yuan",
                        "DKK" => "Danish Krone",
                        "HKD" => "Hong Kong Dollar",
                        "PLN" => "Polish Złoty",
                        "RUB" => "Russian Rouble",
                        "SEK" => "Swedish Krona",
                        "SGD" => "Singapore Dollar",
                        "THB" => "Thai Baht "
                    }
	end

	def help(plugin, topic="")
		return "btc [CURRENCY] : AUD/CAD [USD Default]"
	end

	def do_btc_price(m,params)
    
    cur = params[:symbol].upcase
    if @currency_list.has_key?(cur) 
        api_url = "http://data.mtgox.com/api/2/BTC#{cur}/money/ticker"
        uri = URI.parse(api_url)
        http = Net::HTTP.new(uri.host, uri.port)
        html = http.start do |http|
            req = Net::HTTP::Get.new(uri.path, {"User-Agent" => @user_agent})
            response = http.request(req)
            response.body
        end 

        if html.nil?
            m.reply("Unable to reach MTGOX")
            return
        end
    
        data = JSON.parse(html)
        btc_val = data["data"]["last"]["display"]
        btc_high = data["data"]["high"]["display"]
        btc_low	 = data["data"]["low"]["display"]
        btc_vol = data["data"]["vol"]["display"]

        m.reply sprintf( "#{cur}: %s  High: %s  Low: %s Volume: %s", btc_val, btc_high, btc_low, btc_vol)
    else 
        m.reply("Invalid Currency")
    end

  end
end

plugin = BitcoinPricePlugin.new
plugin.map 'btc [:symbol]', :defaults => {:symbol => "USD"}, :action => 'do_btc_price'

