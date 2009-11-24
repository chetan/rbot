# quietube
# by chetan sarva <cs@pixelcop.net> 2009-11-24
#
# posts shortened quietube version of youtube links with optional title

require '0lib_rbot'
require 'shorturl'

class QuietubePlugin < Plugin

	include PluginLib
	
	Config.register Config::BooleanValue.new("quietube.display_title",
      :default => false,
      :desc => "Fetch and display video title")
	
	def initialize
	    super
	    self.filter_group = :htmlinfo
        load_filters
    end
	
    def listen(m)

        return unless m.kind_of?(PrivMessage)
        
        urls = extract_urls(m)
        urls.each { |url|
            
            next if url !~ %r{http://www\.youtube\.com/watch\?v=}
            
            title = nil
            if @bot.config["quietube.display_title"] then
                # get title
                uri = url.kind_of?(URI) ? url : URI.parse(url)
                info = @bot.filter(:htmlinfo, uri)
                title = info[:title]
                title = " -> #{title}" if not title.nil?
            end
            
            quieter = "http://quietube.com/v.php/#{url}"
            link = ShortURL.shorten(quieter, :tinyurl)
            
            m.reply "quieter: #{link}#{title}"
        }

    end

end 

plugin = QuietubePlugin.new
plugin.register("quietube")