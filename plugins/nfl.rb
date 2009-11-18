# nfl
# by chetan sarva <cs@pixelcop.net> 2008-09-23
#
# display nfl scores

require 'uri/common'
require 'yaml'
require 'tzinfo'
require '0lib_rbot'

class NflPlugin < Plugin

	include PluginLib

	def initialize
		super
		@mynfl = "mynfl => get results for your teams, mynfl [clear] [ team [team...] ] => save your fav teams"
	end
	
	def help(plugin, topic="")
		"nfl => get last nights results, nfl <team> => get results of last game for <team> " + @mynfl
	end
  
  	# get latest results for a specific team
	def nfl_team(m, params)

        params[:teams].each { |team|
        
            info = YahooSports::NFL.get_team_stats(team)
            last_game = info.last5[-1]
            
            game_date = last_game.date.strftime('%a %b %d')
            
            ret = sprintf("%s (%s, %s): %s, %s%s - %s", 
                          info.name, info.standing, info.position, 
                          game_date, (last_game.away ? "at " : ""), last_game.team, last_game.status)
            
            m.reply(ret)
        }
		
	end
	
	def mynfl(m, params)
		
		if not @registry.has_key?(m.sourceaddress)
			m.reply "you need to setup your favs! " + @mynfl
			return
		end

		teams = @registry[m.sourceaddress]
		
		if teams.empty? then
			m.reply "you need to setup your favs! " + @mynfl
			return
		end
		
		params = Hash.new
		teams.each { |t|
			params[:team] = t
			nfl_team(m, params)
		}
			
	end
	
	def set_default(m, params)
	
		teams = params[:teams]
		
		if @registry.has_key?(m.sourceaddress) then
			saved_teams = @registry[m.sourceaddress]
		else
			saved_teams = Array.new
		end
		
		if teams[0] == 'clear' then
			saved_teams.clear
			@registry[m.sourceaddress] = saved_teams
			m.reply 'done'
			return
		elsif teams[0] == 'list' then
			m.reply 'current teams: ' + saved_teams.join(' ')
			return
		end
		
		saved_teams.clear
		teams.each { |t|
			(team, html) = get_team(t)
			saved_teams.push(t) unless team.nil?
		}
		
		@registry[m.sourceaddress] = saved_teams
		m.reply 'saved'
	
	end
  
	def nfl_live(m, params)
	
	    games = YahooSports::NFL.get_homepage_games('live')
	
	    date = Time.parse(eastern_time().strftime('%Y%m%d'))
        show_games(m, games, date, "Live game(s): ", params[:team])
	
	end
	
	def nfl_today(m, params)
	
	    games = YahooSports::NFL.get_homepage_games()
	    
	    date = Time.parse(eastern_time().strftime('%Y%m%d'))
        show_games(m, games, date, "Today's game(s): ")
	
	end
	
	def nfl_yesterday(m, params)
	
	    games = YahooSports::NFL.get_homepage_games()
	    
	    date = Time.parse(eastern_time().strftime('%Y%m%d')) - 86400
        show_games(m, games, date, "Yesterday's game(s): ")
	
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

plugin = NflPlugin.new

plugin.map 'nfl live [:team]', :action => 'nfl_live'
plugin.map 'nfl now [:team]', :action => 'nfl_live'

plugin.map 'nfl today', :action => 'nfl_today'

plugin.map 'nfl yest', :action => 'nfl_yesterday'
plugin.map 'nfl yesterday', :action => 'nfl_yesterday'
plugin.map 'nfl', :action => 'nfl_yesterday'

plugin.map 'nfl *teams', :action => 'nfl_team'

plugin.map 'mynfl', :action => 'mynfl'
plugin.map 'mynfl *teams', :action => 'set_default'
