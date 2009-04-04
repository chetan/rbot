# we gots debt and lots of it!
# by chetan sarva <cs@pixelcop.net> 2008-10-09
#
# lookup the national debt

require 'rubygems'
require 'scrapi'

class DebtPlugin < Plugin

    include PluginLib
	
	def help(plugin, topic="")
		return "debt => get current national debt"
	end

	def do_debt(m,params)
		
        debt = get_national_debt()
        m.reply "unable to get current national debt" if not debt
        m.reply sprintf("Current National Debt: $%s", debt)
		
	end
	
	def get_national_debt()
	
        national_debt = Scraper.define do
            process "table.data1 td:nth-child(4)", :debt => :text
            result :debt
        end
        
        html = fetchurl('http://www.treasurydirect.gov/NP/BPDLogin?application=np')
	    debt = national_debt.scrape(html)
	    return debt
	
	end
	
end 

plugin = DebtPlugin.new
plugin.map 'debt', :action => 'do_debt'

