# oil!
# by chetan sarva <cs@pixelcop.net> 2008-05-30
#
# oil futures price lookup

require 'rubygems'
require 'scrapi'
require 'net/http'

class OilPlugin < Plugin

	def initialize
		super
	end
	
	def help(plugin, topic="")
		return "oil => get current Nymex Crude Future price"
	end

	def crude(m,params)
		
        price = get_crude_price()
        m.reply "unable to get current price" if not price
        m.reply sprintf("Nymex Crude Future: $%s", price)
		
	end
	
	def get_crude_price()
	
        bloomberg_energy = Scraper.define do
        
            array :prices
            process "span.tbl_num", :prices => :text
            result :prices
        end
        
        uri = URI.parse(URI.escape('http://www.bloomberg.com/markets/commodities/energyprices.html'))
        
        http = Net::HTTP.new(uri.host, uri.port)
        html = http.start do |http|
            req = Net::HTTP::Get.new(uri.path, {"User-Agent" => "stickin it to the man"})
            response = http.request(req)
            response.body
        end 
	    
	    prices = bloomberg_energy.scrape(html)

	    return nil if not prices
	    return prices[0]
	
	end
	
end 

plugin = OilPlugin.new
#plugin.map 'oil', :action => 'crude'
plugin.map 'crude', :action => 'crude'

