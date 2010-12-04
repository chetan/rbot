# woot!
#
# by brian ploch <brian -at- ploch.net>
#
# lookup current woot.com daily deal
#
# first line is daily woot
# second line is daily sellout, unless its sold out, 
# then its a random from the deals.woot page
# 
# Version 0.1 2010-06-30

require 'rubygems'
require 'scrapi'
require 'net/http'

class WootPlugin < Plugin

	def initialize
		super
		@woots =["http://www.woot.com/", "http://deals.woot.com/sellout/"]
	end
	
	def help(plugin, topic="")
		return "woot => get current woot deal"
	end

	def woot(m,params)
		
        woot = get_woot()
				p woot
        m.reply "unable to get current woots" if not woot[0].price
        m.reply sprintf("Woot! %s - $%s", woot[0].descrip, woot[0].price)
        m.reply sprintf("Sellout! %s - $%s", woot[1].descrip, woot[1].price)
		
	end
	
def get_woot()
	woot = []
	wc = 0

	@woots.each { |site|

		scraper = Scraper.define do
			process "div.productDescription h2.fn", :descrip => :text
			process "div.productDescription h3.price span.amount", :price => :text
			result :descrip, :price
		end

		uri = URI.parse(site)
		http = Net::HTTP.new(uri.host, uri.port)
		html = http.start do |http|
			req = Net::HTTP::Get.new(uri.path, {"User-Agent" => "Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/533.4 (KHTML, like Gecko) Chrome/5.0.375.55 Safari/533.4"})
			response = http.request(req)
			response.body
		end 

		woot[wc] = scraper.scrape(html)
		wc+=1
	}
	return woot
end

	
end 

plugin = WootPlugin.new
plugin.map 'woot', :action => 'woot'

