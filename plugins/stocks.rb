# stocks
# by ploch
# by chetan sarva <cs@pixelcop.net> 2007-01-23
#
# stock lookup. 
#
# initial lookup by ploch. symbol lookup added by chetan. also the eliteness.

require 'rubygems'
require 'yahoofinance'
require 'json'
require '0lib_rbot'

class StocksPlugin < Plugin

	include PluginLib

	def initialize
		super
		@google_url = 'http://finance.google.com/finance/match?matchtype=matchall&q='
		
		
        # list at http://finance.yahoo.com/futures
        # gold: http://finance.yahoo.com/q/fc?s=GCX08.CMX
        # oil: http://finance.yahoo.com/q/fc?s=CLF09.NYM
        # corn: http://finance.yahoo.com/q/fc?s=CZ08.CBT

        @misc = { 'gold' => 'GCX09.CMX', # nov
                  'oil'  => 'CLZ09.NYM', # dec
                  'corn' => 'CZ09.CBT' } # dec
	end
	
	def help(plugin, topic="")
		return "stocks symbol1  symbol2 ..."
	end
    
    def do_emea(m, params)
        params[:symbols] = [ '^N225', '^HSI', '^FTSE', '^GDAXI' ]
        return do_lookup(m,params)
    end
    
    # futures symbols
    # http://finance.yahoo.com/futures?
    #
    def do_oil(m, params)
        params[:symbols] = [ @misc['oil'] ]
        return do_lookup(m,params)
    end
    
    def do_stocks3(m, params)
        params[:symbols] = [ @misc['gold'], @misc['oil'], @misc['corn'] ]
        return do_lookup(m,params)
    end
    
	def do_lookup(m,params)
		
		if params[:symbols].length == 0 then
		    # no sybmols passed, lookup major indexes
		    params[:symbols].push( '^DJI', '^IXIC', '^GSPC' )
		end
		
		s = params[:symbols].join(" ")
		return m.reply "no symbol(s) entered" if not s
		
        if s =~ /^['"].*['"]$/ then
            # surrounded in quotes, do a symbol lookup using google
            s = s[1..-2]
            begin
                symbols = symbol_lookup(s)
            rescue
                return m.reply $!
            end
            
		else
		    # pass comma separated list of symbols
		    symbols = params[:symbols].join(",")
		    
		end

        _lookup(m, symbols)
		
	end
	
	def _lookup(m, symbol)
	
        responses = get_quotes(symbol)
        if responses.empty? then
            begin
                responses = get_quotes(symbol_lookup(symbol))
                return m.reply( sprintf("no data found for '%s'", symbol) )
            rescue
                debug "dying.... %!"
                return m.reply $!
            end
        end
        
        responses.each do |r|
            m.reply r
        end	
	
	end
	
	def get_quotes(symbols)
	
	    responses = []
		YahooFinance::get_standard_quotes( symbols ).each do |symbol, qt|
		    if valid_quote(qt)
                r = "#{qt.name} (#{symbol}) -> #{qt.lastTrade} Change: #{qt.change} Low: #{qt.dayLow} High: #{qt.dayHigh}"
                r += " Volume: #{qt.volume} " if qt.volume > 0
                responses << r
			end
		end
		
		return responses
	
	end
	
	# returns false if all of these values are 0: 
	# averageDailyVolume, bid, ask, lastTrade, and volume
	def valid_quote(q)
	
	    if q.averageDailyVolume == 0 and q.ask == 0 and q.bid == 0 and q.lastTrade == 0 and q.volume == 0 then
	        return false
	    end
	    
	    return true
	
	end
	
	def symbol_lookup(str)
	
        json_response = fetchurl(sprintf('%s%s', @google_url, str))
        if not json_response then
            raise sprintf('Lookup failed for "%s"', str)
        end
        sugg = JSON.parse(json_response)
        if sugg['matches'].nil? or sugg['matches'].empty? then
            raise sprintf('No symbols found for "%s"', str)
        end
        return sugg['matches'][0]['sugg'][0]
	
	end
		
end 
# GOOG -> 457.37 -4.52 / Last Trade  N/A / Change  -0.98% / Min  457.24 / Max 457.37

plugin = StocksPlugin.new
plugin.map 'stocks [*symbols]', :action => 'do_lookup', :defaults => { :symbols => nil }
plugin.map 'stocks2', :action => 'do_emea'
plugin.map 'stocks3', :action => 'do_stocks3'
plugin.map 'oil', :action => 'do_oil'
