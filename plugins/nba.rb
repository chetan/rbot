# nba
# by chetan sarva <cs@pixelcop.net> 2007-01-23
#
# display nba scores
#
# changelog:
# 2008-05-19 - refactored to use ysports module

require 'uri/common'
require 'yaml'
require 'yahoo_sports'
require '0lib_rbot'

class NbaPlugin < Plugin

	include PluginLib
	
	def initialize
		super
		@mynba = "mynba => get results for your teams, mynba [clear] [ team [team...] ] => save your fav teams"
	end

	def help(plugin, topic="")
		"nba => get last nights results, nba <team> => get results of last game for <team>, mynba => get results for your teams, " + @mynba
	end
  
  	# get latest results for a specific team
	def nba_team(m, params)

        info = YahooSports::NBA.get_team_stats(params[:team])
        last_game = info.last5[-1]
        
        game_date = last_game.date.strftime('%a %b %d')
        
        ret = sprintf("%s (%s, %s): %s, %s%s - %s", 
                      info.name, info.standing, info.position, 
                      game_date, (last_game.away ? "at " : ""), last_game.team, last_game.status)
        
        return m.reply(ret)
		
	end
	
	def nba_playoffs(m, params)
	
		begin
			html = fetchurl('http://sports.yahoo.com/nba/playoffs')
		rescue => ex
			m.reply 'Error fetching url'
			debug ex.inspect
			debug ex.backtrace.join("\n")
			return
		end
	
		if not html then
			m.reply 'Error fetching url'
			return
		end
		
		mteams = html.scan(/<td class=yspscores align=left>(.*?)<\/td>/m)
		teams = Array.new
		mteams.each { |t|
			t = t[0]
			t.gsub!(/&nbsp;/, '')
			t.gsub!(/<a.*?>/, '')
			t.gsub!(/<\/a>/, '')
			t.gsub!(/<b>/, '')
			t.gsub!(/<\/b>/, '')
			t.squeeze!(' ')
			t.strip!
			teams << t
		}
		
		series = html.scan(/<span class="yspdetailttl">(.*?series.*?)<\/span>/m)
		
		games = html.scan(/<tr class=ysprow\d><td height=16 class=yspscores><span class=yspdetailttl>(\d)\.\*?<\/span>(.*?)<\/td><\/tr>/)
		
		series_start = false
		next_games = Array.new
		games.each { |g|
			
			if g[1].include? '<b>' then
				series_start = true

			elsif series_start then
				# at the next game in the series
				desc = /<a href="\/nba\/.*?">(.*?)<\/a> &ndash;(.*)/.match(g[1])
				if desc then 
					next_games << sprintf('Game %s %s %s', g[0], desc[1], desc[2].gsub(/&n.*?;/, '').squeeze(' ').strip)
				else
					next_games << sprintf('Game %s %s', g[0], g[1].gsub(/&n.*?;/, '').squeeze(' ').strip)
				end
				series_start = false
			end
			
		}
		
		series.each_index { |i|
			m.reply sprintf('%s: %s, %s', teams[i], series[i][0].gsub(/&nbsp;/, '').strip, next_games[i])
		}

		
	end
	
	def mynba(m, params)
		
		if not @registry.has_key?(m.sourceaddress)
			m.reply("you need to setup your favs! " + @mynba)
			return
		end

		teams = @registry[m.sourceaddress]
		
		if teams.empty? then
			m.reply("you need to setup your favs! " + @mynba)
			return
		end
		
		params = Hash.new
		teams.each { |t|
			params[:team] = t
			nba_team(m, params)
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
			m.reply('done')
			return
		elsif teams[0] == 'list' then
			m.reply('current teams: ' + saved_teams.join(' '))
			return
		end
		
		saved_teams.clear
		teams.each { |t|
			(team, html) = YahooSports::NBA.find_team_page(t)
			saved_teams.push(t) unless team.nil?
		}
		
		@registry[m.sourceaddress] = saved_teams
		m.reply('saved')
	
	end
	
	def nba_live(m, params)
	
	    games = YahooSports::NBA.get_homepage_games('live')
	
	    date = Time.parse(eastern_time().strftime('%Y%m%d'))
        show_games(m, games, date, "Live games: ")
	
	end
	
	def nba_today(m, params)
	
	    games = YahooSports::NBA.get_homepage_games()
	    
	    date = Time.parse(eastern_time().strftime('%Y%m%d'))
        show_games(m, games, date, "Today's games: ")
	
	end
	
	def nba_yesterday(m, params)
	
	    games = YahooSports::NBA.get_homepage_games()
	    
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

plugin = NbaPlugin.new

plugin.map 'nba live', :action => 'nba_live'
plugin.map 'nba now', :action => 'nba_live'

plugin.map 'nba today', :action => 'nba_today'

plugin.map 'nba yest', :action => 'nba_yesterday'
plugin.map 'nba yesterday', :action => 'nba_yesterday'
plugin.map 'nba', :action => 'nba_yesterday'

plugin.map 'nba :team', :action => 'nba_team'

plugin.map 'mynba', :action => 'mynba'
plugin.map 'mynba *teams', :action => 'set_default'

plugin.map 'nbap', :action => 'nba_playoffs'
plugin.map 'nbaplayoffs', :action => 'nba_playoffs'
