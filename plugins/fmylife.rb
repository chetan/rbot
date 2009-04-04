# fmylife!
# by chetan sarva <cs@pixelcop.net> 2009-03-20
#
# scrape from fmylife.com

require 'rubygems'
require 'scrapi'
require '0lib_rbot'

class FMyLifePlugin < Plugin

    include PluginLib

	def initialize
		super
		@url = 'http://www.fmylife.com/'
	end
	
	def help(plugin, topic="")
		return "fml => get random entry from fmylife.com"
	end

	def do_fml(m, params)
		
		if params[:num] then
		    num = params[:num].gsub('#', '')
            url = @url + num
        else
            url = @url + 'random'
		end
		
		posts = scrape_fml(url)
		
		return m.reply "error getting posts from fmylife.com" if not posts
				
		posts = posts.sort_by { rand }
		p = posts[0]
		m.reply sprintf("%s: %s", p.num, p.text)
		
	end
	
	def scrape_fml(url)
	    
	    html = fetchurl(url)
	    
	    fml_post = Scraper.define do
            process_first "p", :text => :text
            process_first "div.date a", :num => :text
	        result :num, :text
        end
	    
        fml_posts = Scraper.define do
            array :posts
            process "div.post", :posts => fml_post
            result :posts
        end
	    posts = fml_posts.scrape(html)
	    
	    posts.delete_if { |p| p.num.nil? }
	    posts.each { |p| strip_tags(p.text) }

	    return posts
	end
	
end 

plugin = FMyLifePlugin.new
plugin.map 'fml [:num]', :action => 'do_fml'

