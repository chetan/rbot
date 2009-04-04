# tiny weather script
# by chetan sarva <cs@pixelcop.net> 2009-03-20
#
# scrapes weather.com

require 'rubygems'
require 'scrapi'
require '0lib_rbot'

class TinyWeatherPlugin < Plugin

    include PluginLib

	def initialize
		super
		@url = 'http://www.weather.com/outlook/travel/businesstraveler/hourbyhour/graph/'
	end
	
	def help(plugin, topic="")
		return "tw <zip> => get hourly forecast from weather.com"
	end

	def do_tiny_weather(m, params)
		
		if params[:zip] then
            url = @url + params[:zip]
        else
            return m.reply "zipcode is required!"
		end
		
		w = scrape_weather(url)
		
		return m.reply "error getting weather" if not w

        s = [w.location]
        i = 0
        w.hours.each { |h|
            i += 1
            next if i % 2 == 0
            s << sprintf("%s: %s (%s)", h.hour, h.temp, h.precip)
            
        }
				
		m.reply s.join('   ')
		
	end
	
	def scrape_weather(url)
	    
	    html = fetchurl(url)
	    
	    hour_scraper = Scraper.define do
            process "div.hbhWxTime div", :hour => :text
            process_first "div.hbhWxTemp div", :temp => :text
            process_first "div.hbhWxPrecip div", :precip => :text
	        result :hour, :temp, :precip
        end
	    
        hourly_scraper = Scraper.define do
            array :hours
            process "div.hbhWxHour", :hours => hour_scraper
            process "div#hbhModulePad > h1 > span", :location => :text
            result :location, :hours
        end
	    w = hourly_scraper.scrape(html)
	    w.hours.each { |h|
	        h.temp.gsub!('&#176; ', '')
	        h.precip.gsub!("Precip:\n", '')
        }
        return w
       
	end
	
end 

plugin = TinyWeatherPlugin.new
plugin.map 'tw :zip', :action => 'do_tiny_weather'

