#
# upcoming dvd release list with date
#
# by brian ploch <brian -at- ploch.net>
#
# retrieve upcoming dvd releases with dates from moviefone.com
#
# version 0.1 2010-06-27
#
# TODO:
# 	add search by title for upcoming movies
#
require 'rubygems'
require 'scrapi'
require 'net/http'

class DVD_ReleasePlugin < Plugin

	Config.register Config::IntegerValue.new("dvd_release.display_limit",
		:default => 5,
		:desc	=>	"Amount of dvds to list")
	
	def initialize
		super
		@dvd_coming_url = "http://www.moviefone.com/dvd/coming-soon"
		@dvd_recent_url = "http://www.moviefone.com/dvd/dvd-release-date"
		@user_agent = "Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/533.4 (KHTML, like Gecko) Chrome/5.0.375.55 Safari/533.4"
	end

	def help(plugin, topic="")
		return "dvd new: (default) to view a list of upcoming dvd releases; dvd out: to see recently released"
	end

	def get_dvd_release(m,params)

		scraper = Scraper.define do
			array :dvds
			process "div.movie", :dvds => Scraper.define {
				process "a.movieTitle", :name => :text
				process "div.movie div.thisWeekCont div.thisWeek", :date => :text
				result :name,:date
			}
			result :dvds
		end

		if params[:type] == "out"
			dvd_url = @dvd_recent_url
		else
			dvd_url = @dvd_coming_url
		end

		uri = URI.parse(dvd_url)
		http = Net::HTTP.new(uri.host, uri.port)
		html = http.start do |http|
			req = Net::HTTP::Get.new(uri.path, {"User-Agent" => @user_agent})
			response = http.request(req)
			response.body
		end 
	
		unless html
			m.reply "Unable to retrieve movie data"
			return
		end

		dvdData = scraper.scrape(html)
		limit = 1

		dvdData.each do |dvd| 
			m.reply "%s: %s" % [dvd.date, dvd.name] 
			if limit == (@bot.config['dvd_release.display_limit'])
				break
			end

			limit+=1

		end
	end
end

plugin = DVD_ReleasePlugin.new
plugin.map	'dvd [:type]', :defaults => {:type => "new"},:action => 'get_dvd_release'
