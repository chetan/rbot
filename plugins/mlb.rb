# mlb
# by chetan sarva <cs@pixelcop.net> 2007-01-23
#
# display mlb scores

require 'uri/common'
require 'yaml'
require 'tzinfo'
require '0lib_rbot'

class MlbPlugin < Plugin

	include PluginLib

	def initialize
		super
		@mymlb = "mymlb => get results for your teams, mymlb [clear] [ team [team...] ] => save your fav teams"
	end
	
	def help(plugin, topic="")
		"mlb => get last nights results, mlb <team> => get results of last game for <team> " + @mymlb
	end
  
  	# get latest results for a specific team
	def mlb_team(m, params)

        info = YahooSports::MLB.get_team_stats(params[:team])
        last_game = info.last5[-1]
        
        game_date = last_game.date.strftime('%a %b %d')
        
        ret = sprintf("%s (%s, %s): %s, %s%s - %s", 
                      info.name, info.standing, info.position, 
                      game_date, (last_game.away ? "at " : ""), last_game.team, last_game.status)
        
        return m.reply(ret)
		
	end
	
	def mymlb(m, params)
		
		if not @registry.has_key?(m.sourceaddress)
			m.reply "you need to setup your favs! " + @mymlb
			return
		end

		teams = @registry[m.sourceaddress]
		
		if teams.empty? then
			m.reply "you need to setup your favs! " + @mymlb
			return
		end
		
		params = Hash.new
		teams.each { |t|
			params[:team] = t
			mlb_team(m, params)
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
  
	def mlb_live(m, params)
	
	    games = YahooSports::MLB.get_homepage_games('live')
	
	    date = Time.parse(eastern_time().strftime('%Y%m%d'))
        show_games(m, games, date, "Live game(s): ", params[:team])
	
	end
	
	def mlb_today(m, params)
	
	    games = YahooSports::MLB.get_homepage_games()
	    
	    date = Time.parse(eastern_time().strftime('%Y%m%d'))
        show_games(m, games, date, "Today's game(s): ")
	
	end
	
	def mlb_yesterday(m, params)
	
	    games = YahooSports::MLB.get_homepage_games()
	    
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

plugin = MlbPlugin.new

plugin.map 'mlb live [:team]', :action => 'mlb_live'
plugin.map 'mlb now [:team]', :action => 'mlb_live'

plugin.map 'mlb today', :action => 'mlb_today'

plugin.map 'mlb yest', :action => 'mlb_yesterday'
plugin.map 'mlb yesterday', :action => 'mlb_yesterday'
plugin.map 'mlb', :action => 'mlb_yesterday'

plugin.map 'mlb :team', :action => 'mlb_team'

plugin.map 'mymlb', :action => 'mymlb'
plugin.map 'mymlb *teams', :action => 'set_default'
