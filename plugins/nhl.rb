# nhl
# by chetan sarva <cs@pixelcop.net> 2007-01-23
#
# display nhl scores

require 'yahoo_sports'
require '0lib_rbot'

class NhlPlugin < Plugin

	include PluginLib
	
	def help(plugin, topic="")
		"nhl => get last nights results, nhl <team> => get results of last game for <team>"
	end
  
  	# get latest results for a specific team
	def nhl_team(m, params)

        info = YahooSports::NHL.get_team_stats(params[:team])
        last_game = info.last5[-1]
        
        game_date = last_game.date.strftime('%a %b %d')
        
        ret = sprintf("%s (%s, %s): %s, %s%s - %s", 
                      info.name, info.standing, info.position, 
                      game_date, (last_game.away ? "at " : ""), last_game.team, last_game.status)
        
        return m.reply(ret)
		
	end
	
	def nhl_live(m, params)
	
	    games = YahooSports::NHL.get_homepage_games('live')
	
	    date = Time.parse(eastern_time().strftime('%Y%m%d'))
        show_games(m, games, date, "Live games: ")
	
	end
	
	def nhl_today(m, params)
	
	    games = YahooSports::NHL.get_homepage_games()
	    
	    date = Time.parse(eastern_time().strftime('%Y%m%d'))
        show_games(m, games, date, "Today's games: ")
	
	end
	
	def nhl_yesterday(m, params)
	
	    games = YahooSports::NHL.get_homepage_games()
	    
	    date = Time.parse(eastern_time().strftime('%Y%m%d')) - 86400
        show_games(m, games, date, "Yesterday's games: ")
	
	end
	
	def show_games(m, games, date, text, team = '')
	
	    scores = []
	
	    games.each { |game|
	    
	    	next if not team.nil? and not team.empty? and not
	    			(game.team1.downcase.include? team or 
	    			 game.team2.downcase.include? team)

	        next if Time.parse(game.date.strftime('%Y%m%d')) != date   

	        if game.state == 'preview' then
                game.status = sprintf("%s, %s", game.status, game.extra) if game.extra
	            scores << sprintf("%s at %s (%s, %s)", game.team1, game.team2, game.state, game.status)
                next
            end

	        if game.state == 'final' then
	            if game.score1.to_i > game.score2.to_i then
                    game.team1 += '*'
                else
                    game.team2 += '*'
                end
                game.status = 'F'
            else
                # live
                game.status = sprintf('%s, %s', game.state, game.status)
            end

	        scores << sprintf("%s %s at %s %s (%s)", 
                               game.team1, game.score1, 
                               game.team2, game.score2, 
                               game.status.strip)
	    }
	    
	    return m.reply(text + 'none') if scores.empty?

	    m.reply(text + scores.join(' / '))
	
	end
  
end

plugin = NhlPlugin.new

plugin.map 'nhl live', :action => 'nhl_live'
plugin.map 'nhl now', :action => 'nhl_live'

plugin.map 'nhl today', :action => 'nhl_today'

plugin.map 'nhl yest', :action => 'nhl_yesterday'
plugin.map 'nhl yesterday', :action => 'nhl_yesterday'
plugin.map 'nhl', :action => 'nhl_yesterday'

plugin.map 'nhl :team', :action => 'nhl_team'
