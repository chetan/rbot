
require 'ostruct'
require 'scrapi'
require 'htmlentities'

module YSports

class MLB < Base

    def self.get_homepage_games(state = '')
        return super('mlb', state)
    end
    
    def self.find_team_page(str)
    
        begin
            html = YSports.fetchurl('http://sports.yahoo.com/mlb/teams/' + str)
        rescue => ex
            puts ex
            return
        end
        
        search = false
        teams = nil
        if /<h1 class="yspseohdln"><\/h1>/.match(html) then
            # invalid 3 letter code was entered, find a matching team name
            search = true
            teams = html.scan(/<option value="\/mlb\/teams\/(.*?)">(.*?)<\/option>/)    
            
        elsif /<title>MLB - Teams - Yahoo! Sports<\/title>/.match(html) then
            # invalid team name entered, see if we can find it
            search = true
            teams = html.scan(/<a href=\/mlb\/teams\/(.*?)>(.*?)<\/a>/)
            
        end
        
        if search then
            # look for team name
            q = str.downcase
            team = teams.find { |t| 
                t[1].downcase == q or t[1].downcase.include? q 
            }
            
            return nil if not team
            
            # found a likely match, load their page
            return [ team[0], YSports.fetchurl('http://sports.yahoo.com/mlb/teams/' + team[0]) ]
            
        end
        
        return [ str, html ]
    
    end
    
    def self.get_team_stats(str)

        (team, html) = find_team_page(str)
        if html.nil? then
            raise sprintf("Can't find team '%s'", str)
        end
        
        
        info_scraper = Scraper.define do
        
            array :teams
            array :scores
            
            process "h1.yspseohdln:first-child", :name => :text
            process "p.team-standing", :standing => :text
            
            result :name, :standing
            
        end
        
        games_scraper = Scraper.define do
        
            array :games
            
            process "tr.ysprow2 > td.yspscores, tr.ysprow1 > td.yspscores", :games => :text
            
            result :games
            
        end
        
        info = info_scraper.scrape(html)
        
        games_temp = games_scraper.scrape(html)
        games_temp = games_temp[games_temp.length-30, games_temp.length]
        
        last5 = []
        next5 = []
        
        games_temp.each_index { |i|
            next if i % 3 != 0
            gm = OpenStruct.new({:date => 
                                    Time.parse(YSports.strip_tags(games_temp[i])),
                                 :team => games_temp[i+1],
                                 :status => YSports.strip_tags(games_temp[i+2])})

            if gm.team[0,2] == 'at' then
                gm.away = 1
                gm.team = gm.team[3, gm.team.length]
            else
                gm.away = 0
            end
                        
            if gm.status =~ /^(W|L)/
                last5 << gm 
            else
                next5 << gm
            end
            
        }
        
        return OpenStruct.new({:name => info.name,
                               :standing => info.standing,
                               :last5 => last5,
                               :next5 => next5})
        
    end

end

end
