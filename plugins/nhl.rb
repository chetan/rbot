# nhl
# by chetan sarva <cs@pixelcop.net> 2007-01-23
#
# display nhl scores

require 'ysports'
require '0lib_rbot'

class NhlPlugin < Plugin

	include PluginLib
	
	def help(plugin, topic="")
		"nhl => get last nights results, nhl <team> => get results of last game for <team>"
	end
  
  	# get latest results for a specific team
	def nhl_team(m, params)
	
        m.reply "needs rewrite"
    
#		m.reply sprintf("%s (%s): %s %s - %s", name, rank, matches[1].strip, matches[3].strip, matches[6].strip)

# 			if not name.include? teams[0][0] then
# 			    live_game['away'] = 0
# 			    live_game['team'] = 
# 				vs = 'vs ' + teams[0][0]
# 			else
# 				vs = 'at ' + teams[1][0]
# 			end
# 			m.reply sprintf("%s (%s): %s %s %s - %s (live)", name, rank, Time.now.strftime("%b %d, %Y"), vs, scores[0], scores[1])
		
	end
	
	def nhl_live(m, params)
	
	    games = YSports::NHL.get_homepage_games('live')
	
	    date = Time.parse(eastern_time().strftime('%Y%m%d'))
        show_games(m, games, date, "Live games: ")
	
	end
	
	def nhl_today(m, params)
	
	    games = YSports::NHL.get_homepage_games()
	    
	    date = Time.parse(eastern_time().strftime('%Y%m%d'))
        show_games(m, games, date, "Today's games: ")
	
	end
	
	def nhl_yesterday(m, params)
	
	    games = YSports::NHL.get_homepage_games()
	    
	    date = Time.parse(eastern_time().strftime('%Y%m%d')) - 86400
        show_games(m, games, date, "Yesterday's games: ")
	
	end
	
	def show_games(m, games, date, text, team = '')
	
	    scores = []
	
	    games.each { |game|
	    
	    	next if not team.nil? and not team.empty? and not
	    			(game.team1.downcase.include? team or 
	    			 game.team2.downcase.include? team)
	    
	        if game.date == date then
	            if game.state == 'preview' then
                    game.status = sprintf("%s, %s", game.status, game.extra) if game.extra
	                scores << sprintf("%s at %s (%s, %s)", game.team1, game.team2, game.state, game.status)
	            else
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
                                       
	            end
	        end
	    
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
