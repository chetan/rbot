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

    # Massillon, OH (44647)   11 am: 63F (10%)   1 pm: 72F (10%)   3 pm: 76F (10%)   5 pm: 75F (10%)   no rain :)
    def do_tiny_weather(m, params)

        zip = check_zip(m, params)
        return if zip.nil?

        w = nil
        begin
            w = scrape_hourly_weather(zip)
        rescue => ex
        end
        return m.reply("error getting hourly weather") if not w

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

    # Massillon, OH (44647)   11 am: 63F (10%)   1 pm: 72F (10%)   3 pm: 76F (10%)   5 pm: 75F (10%)   no rain :)
    # Massillon, OH (44647)   Sat: 86F (40%)   Sun: 80F (10%)   Mon: 79F (0%)   Tue: 80F (10%)   Wed: 83F (30%)   Thu: 81F (60%)
    def do_tiny_weather_forecast(m, params)

        zip = check_zip(m, params)
        return if zip.nil?

        do_tiny_weather(m, params) # do this first

        w = nil
        begin
            w = scrape_weather_forecast(zip)
        rescue => ex
        end
        return m.reply("error getting weather forecast") if not w

        s = [ w.location ]
        date = Time.new
        w.temps.each_with_index { |d, i|
            next if i == 0
            date += 86400
            day = date.strftime("%a")
            high = w.temps[i] + "F"
            precip = w.precips[i] + "%"
            s << sprintf("%s: %s (%s)", day, high, precip) # Sun: 80F (10%)
            break if i == 6 # only want to show the next 6 days
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

        html = fetchurl('http://www.weather.com/weather/tenday/' + zip)

        fc_scraper = Scraper.define do
            array :temps, :precips
            process "td.twc-forecast-temperature", :temps => :text
            process "td.twc-line-precip", :precips => :text
            process_first "h1#twc_loc_head", :location => :text
            result :location, :temps, :precips
        end

        w = fc_scraper.scrape(html)

        # cleanup results
        w.location.gsub!(/\s+Weather\s*$/, '')
        w.location.strip!

        w.temps = w.temps[0,10] # first 10 are high temps
        w.temps.first.gsub!(/F High/, '')
        w.temps.each { |t| t.gsub!('&#176;', '') }

        w.precips = w.precips.map { |t| t =~ /(\d+)/; $1 }

        return w
    end

end

plugin = TinyWeatherPlugin.new
plugin.map 'tw default :zip', :action => 'do_set_default'
plugin.map 'tw [:zip]', :action => 'do_tiny_weather'
plugin.map 'twf [:zip]', :action => 'do_tiny_weather_forecast'
