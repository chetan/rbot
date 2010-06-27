# 
#
# steam profile info
#
# by brian ploch <brian -at- ploch.net>
#
# basic profile information lookup based on profile name or steam64 id
#
#
# Version: 0.2 2010-06-26
# 	Complete rewrite + made public
#
#
#
# TODO (?)
#
# parse stateMessage and show current game being played
#
# show friend summery for online, offline, games being played + counts
#
# anything else? 
#

require 'rexml/document'

class SteamPlugin < Plugin

  include REXML

  def initialize
    super
    @steam_id_base = "http://steamcommunity.com/id/"
    @steam_profile_base = "http://steamcommunity.com/profiles/"
  end

  def help(plugin, topic="")
    return "steam [user]=> get info on steam user; steam setaccount [account] => set default steam account"
  end

  def send_steam_info(m,account_name,player_info,game_data)

    m.reply "#{Bold}Steam status for #{NormalText}%s: #{Bold}Currently:#{NormalText} %s\n#{Bold}Game Name:#{NormalText} %s #{Bold}Rating: #{NormalText}%s #{Bold}Playtime (2 weeks): #{NormalText}%s hours" %  
      [  account_name , player_info["online_status"], player_info["current_name"],  player_info["steam_rating"],  player_info["hours_2week"] ]

    top_games = "#{Bold}Most Recent Games #{NormalText}[2 weeks/Total]: "
    game_data.each { |g| top_games += "#{Bold} #{g['game']}#{NormalText} [#{g['time']}h/#{g['total']}h] " }
    m.reply "#{top_games}"

  end

  def steam_profile_lookup(m,params)
    if params[:account]

      games,player_info,friend_info = steam_fetch_profile(params[:account])
      send_steam_info(m,params[:account],player_info,games)

    elsif @registry.has_key? "#{m.sourceaddress}_steamuser" then

      games,player_info,friend_info = steam_fetch_profile(@registry["#{m.sourceaddress}_steamuser"])
      send_steam_info(m,@registry["#{m.sourceaddress}_steamuser"],player_info,games)

    else
      m.reply "Please specify an account name or set a default \"steam setaccount <account or id>\""
    end

    return
  end

  # return steam url based on account
  def steam_user_url(account_name)
    if account_name.is_a? Numeric
      return @steam_profile_base + account_name + "/?xml=1"
    else
      return @steam_id_base + account_name + "/?xml=1"
    end
  end

  def steam_fetch_profile(account_name)

    gamedata = Array.new
    player_info ={}
    friend_info ={}

    steam_url = steam_user_url(account_name)

    begin
      file = @bot.httputil.get(steam_url, :cache => false)
      raise unless file
    rescue => e
      m.reply "Unable to fetch steam xml data"
      return
    end

    doc = Document.new(file)

    player_info['current_name'] = XPath.first(doc, "//steamID").text
    player_info['online_status']= XPath.first(doc, "//onlineState").text
    player_info['online_msg']   = XPath.first(doc, "//stateMessage").text
    player_info['member_time']  = XPath.first(doc, "//memberSince").text
    player_info['steam_rating'] = XPath.first(doc, "//steamRating").text
    player_info['hours_2week']  = XPath.first(doc, "//hoursPlayed2Wk").text

    # get game list, time, total time for last 2 weeks
    doc.elements.each("//mostPlayedGame") { |g|
      game = g.elements["gameName"].text
      time = g.elements["hoursPlayed"].text
      ttime= g.elements["hoursOnRecord"].text

      gamedata << Hash['game'=> game,'time' => time,'total'=>ttime]
    }

    # retrieve friends and their status (summary only)
    doc.elements.each("//friend") { |f|
      friend_info[f.elements["steamID"].text] = f.elements["stateMessage"].text
    }

    return gamedata,player_info,friend_info

  end


  def set_default_account(m,params)
    if not params[:account] then
      return m.reply "Missing account name for setting a default account."
    end
  
    @registry["#{m.sourceaddress}_steamuser"] = params[:account]
    m.reply "%s has been set as your steam account." % params[:account]
  end 

end

plugin = SteamPlugin.new
plugin.map  'steam setaccount [:account]', :action => 'set_default_account'
plugin.map  'steam [:account]', :action => 'steam_profile_lookup'
