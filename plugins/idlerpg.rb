require 'rubygems'
require 'open-uri'
require 'rexml/document'
require 'duration'
require 'scrapi'
require '0lib_rbot'

# to pull idle rpg player infoz 
#

class IdleRpgPlugin < Plugin

	include REXML
	include PluginLib

	def help(plugin,topic="")
		"irpg [player]..."
	end

    def do_playerinfo(m, params)
  
        params[:user] = m.sourcenick.downcase if params[:user].empty?
    
        params[:user].each { |user|
            url = sprintf("http://rpg.znx.no/xml.php?player=%s",user)
            xml = open(url)
        
            unless xml
                m.reply "problem getting stats for " + user
                return
            end
            
            doc = Document.new xml
            unless doc
                m.reply "parse failed (invalid xml) for " + user
                return
            end
            
            level  = doc.elements["//level"].text
            pclass = doc.elements["//class"].text
            isonline = doc.elements["//online"].text
            psum = doc.elements["//items/total"].text
            nlvl = doc.elements["//ttl"].text
            a_desc= doc.elements["//alignment"].text
            
            rank = get_rank(user)
    
            if isonline == "1"
                online = "Yes"
                online_s = "online :)"
            else
                online = "No"
                online_s = "offline :("
            end
    
            if a_desc == "e" 
                align = "Evil"
            elsif a_desc =="n"
                align = "Neutral"
            elsif a_desc =="g"
                align = "Good"
            end
    
            if level != nil
                lvltime = Duration.new(nlvl)
            
                #m.reply sprintf("%s: Rank: %s Level: %s Class: %s Alignment: %s  Online: %s Item Score: %s Next level in %s", user, rank, level, pclass, align, online, psum, lvltime)
                
                m.reply sprintf("%s: (rank: %s, level: %s) is %s next level in %s", user, rank, level, online_s, lvltime)
            
            end
        }
    
    end
    
    def get_rank(player)
    
        html = fetchurl('http://rpg.znx.no/players.php')
        if not html then
            return -1
        end
        
        irpg_player = Scraper.define do
            array :players
            process "ol > li > a", :players => :text           
            result :players
        end
        
        players = irpg_player.scrape(html)
        
        players.each_with_index {|item, index|
            return index + 1 if item == player
        }
    
    end

end

plugin = IdleRpgPlugin.new
plugin.map 'irpg [*user]', :action => 'do_playerinfo'
