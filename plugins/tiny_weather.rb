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
	end
	
	def help(plugin, topic="")
		return "tw [zip] => get hourly forecast from weather.com; tw default <zip> => set your default zipcode"
	end

	def do_tiny_weather(m, params)
		
        zip = check_zip(m, params)
		return if zip.nil?
		
		w = scrape_hourly_weather(zip)
		return m.reply("error getting weather") if not w

        s = [w.location]
        i = 0
        precip = 0
        w.hours.each { |h|
            i += 1
            precip = h.precip.to_i if h.precip.to_i > precip
            next if i % 2 == 0
            s << sprintf("%s: %s (%s)", h.hour, h.temp, h.precip)
        }
        
        if precip < 30 then
            s << "no rain :)"
        elsif precip == 30 or precip == 40 then
            s << "might want that umbrella"
        else
            s << "grab an umbrella!"
        end
				
		m.reply(s.join('   '))
		
	end
	
	def do_tiny_weather_forecast(m, params)
	    
	    zip = check_zip(m, params)
		return if zip.nil?
		
		do_tiny_weather(m, params) # do this first
		
		w = scrape_weather_forecast(zip)
		return m.reply("error getting weather") if not w
		
		s = [w.location]
		w.days.each_with_index { |d, i| 
		    next if i == 0
		    day = d.date.split[0]
		    high = d.temps.split("\n")[0] + "F"
		    s << sprintf("%s: %s (%s)", day, high, d.precip)
		    break if i > 5
	    }
		
	    m.reply(s.join('   '))
    end
    
    def check_zip(m, params)
        
       	if params[:zip] then
            zip = params[:zip]
            
            # store it if we have nothing on file for them
            if not @registry.has_key? m.sourceaddress then
                @registry[m.sourceaddress] = params[:zip]
                m.reply("hi %s. I went ahead and set %s as your default zip. You can change it with the command tw default <zip>" % [ m.sourcenick, params[:zip] ])
            end
            
            return zip
            
        elsif @registry.has_key? m.sourceaddress then
            return @registry[m.sourceaddress]
            
        else
            m.reply("zipcode is required the first time you call me")
            return nil
		end
		 
    end
	
	def do_set_default(m, params)
	
	    if not params[:zip] then
	        return m.reply("%s, I can't very well set a new default for you without a zipcode, can I?" % m.sourcenick)
	    end

	    @registry[m.sourceaddress] = params[:zip]
	    m.reply "%s, your default zip has been set to %s" % [ m.sourcenick, params[:zip] ]
	    
	    # and give em the weather while we're at it
	    do_tiny_weather(m, params)
	    
	end
	
	def scrape_hourly_weather(zip)
	    
	    html = fetchurl('http://www.weather.com/outlook/travel/businesstraveler/hourbyhour/graph/' + zip)
	    
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
	
	def scrape_weather_forecast(zip)
	    
	    html = fetchurl('http://www.weather.com/outlook/travel/businesstraveler/tenday/' + zip)
	    
	    day_scraper = Scraper.define do
	        process "div.tdDate", :date => :text
	        process "div.tdTemps", :temps => :text
	        process "div.tdPrecip", :precip => :text
	        result :date, :temps, :precip
        end
	    
	    fc_scraper = Scraper.define do
	        array :days
	        process "div.tdWrap", :days => day_scraper
	        process_first "td.module h2.moduleTitleBarGML", :location => :text
	        result :location, :days
        end
        
        w = fc_scraper.scrape(html)
        
        # cleanup results
        w.location = w.location.split("\n")[1]
        w.days.each { |d|
            d.date = cleanup_html(d.date).gsub(/\n/, ' ')
            d.temps = cleanup_html(d.temps, true)
            d.precip = cleanup_html(d.precip)
        }
	    
	    return w
	    
    end
	
end

plugin = TinyWeatherPlugin.new
plugin.map 'tw default :zip', :action => 'do_set_default'
plugin.map 'tw [:zip]', :action => 'do_tiny_weather'
plugin.map 'twf [:zip]', :action => 'do_tiny_weather_forecast'


