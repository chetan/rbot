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
        w.highs.each_with_index { |high, i|
            next if i == 0 # skip todays forecast
            date += 86400
            day = date.strftime("%a")
            precip = w.precips[i]
            s << sprintf("%s: %s (%s)", day, high, precip) # Sun: 80F (10%)
            break if i == 6 # only want to show the next 6 days
        }

        m.reply(s.join('   '))
    end

    def get_sourceaddress(m)
        source = m.sourceaddress
        (ident, host) = source.split(/@/)
        quads = host.split(/\./)
        if quads.size > 3 then
            source = "#{ident}@*." + quads[quads.size-3,quads.size].join(".")
        end
        return source
    end

    def check_zip(m, params)

        source = get_sourceaddress(m)

        if params[:zip] then
            zip = params[:zip]

            # store it if we have nothing on file for them
            if not @registry.has_key? source then
                @registry[source] = params[:zip]
                m.reply("hi %s. I went ahead and set %s as your default zip. You can change it with the command tw default <zip>" % [ m.sourcenick, params[:zip] ])
            end

            return zip

        elsif @registry.has_key? source then
            return @registry[source]

        else
            m.reply("zipcode is required the first time you call me")
            return nil
        end

    end

    def do_set_default(m, params)

        source = get_sourceaddress(m)

        if not params[:zip] then
            return m.reply("%s, I can't very well set a new default for you without a zipcode, can I?" % m.sourcenick)
        end

        @registry[source] = params[:zip]
        m.reply "%s, your default zip has been set to %s" % [ m.sourcenick, params[:zip] ]

        # and give em the weather while we're at it
        do_tiny_weather(m, params)

    end

    def scrape_hourly_weather(zip)

        html = fetchurl("http://www.weather.com/weather/hourbyhour/graph/#{zip}?pagenum=2&nextbeginIndex=0")

        hour_scraper = Scraper.define do
            process "h3.wx-time", :hour => :text
            process_first "div.wx-conditions p.wx-temp", :temp => :text
            process_first "div.wx-details dl:nth-child(3) dd", :precip => :text
            result :hour, :temp, :precip
        end

        hourly_scraper = Scraper.define do
            array :hours
            process "div.wx-timepart", :hours => hour_scraper
            process "div.wx-location-title > h1", :location => :text
            result :location, :hours
        end
        w = hourly_scraper.scrape(html)
        w.hours.each { |h|
            if h.hour =~ /^(\d+ [A-Z]{2})/ then
              h.hour = $1
              h.hour.downcase!
            end
            clean(h.temp, 'F')
            clean(h.precip, '%')
        }

        w.location.gsub!(/\s+Weather\s*$/, '')
        w.location.strip!

        return w
    end

    def clean(str, replace='')
      str.gsub!(/&#176;.?/, replace)
    end

    def scrape_weather_forecast(zip)

        html = fetchurl('http://www.weather.com/weather/tenday/' + zip)

        fc_scraper = Scraper.define do
            array :highs, :lows, :precips
            process "p.wx-temp",     :highs => :text
            process "p.wx-temp-alt", :lows  => :text
            process "div.wx-details dl dd", :precips => :text
            process_first "div.wx-location-title > h1", :location => :text
            result :location, :highs, :lows, :precips
        end

        w = fc_scraper.scrape(html)

        # cleanup results
        w.location.gsub!(/\s+Weather\s*$/, '')
        w.location.strip!

        w.highs.each { |h| clean(h, 'F') }
        w.lows.each { |h| clean(h, 'F') }
        w.precips.each { |h| clean(h, '%') }
        w.precips = w.precips.find_all { |h| h =~ /%$/ }

        return w
    end

end

plugin = TinyWeatherPlugin.new
plugin.map 'tw default :zip', :action => 'do_set_default'
plugin.map 'tw [:zip]', :action => 'do_tiny_weather'
plugin.map 'twf [:zip]', :action => 'do_tiny_weather_forecast'
