# BoxOffice
# by chetan sarva <cs@pixelcop.net> 2007-01-25
#
# display box office numbers

require 'uri/common'
require '0lib_rbot'

class BoxOffficePlugin < Plugin

  include PluginLib

  def help(plugin, topic="")
    "boxoffice|bo => get latest box office numbers (top 5)"
  end

  # get boxoffice numbers for a specific movie
  def boxoffice_movie(m, params)

    movie = params[:movie].join(' ').downcase
    html = fetchurl('http://www.boxofficemojo.com/search/?p=.htm&q=' + movie)

    found = false
    a = nil
    movies = Array.new
    html.scan(/<a href="(\/movies\/\?id=.*?.htm)">(.*?)<\/a>.*?<a href="\/schedule\/\?view=.*?">(.*?)<\/a>/m) { |a|
      if a[1].downcase == movie
        found = true
        break
      end
      movies << [ a ]
    }

    if found
      # found it, show score
      lookup_movie(m, a[1], 'http://www.boxofficemojo.com' + a[0])
      return

    else

      # no exact match, print some choices
      if movies.length == 0
        m.reply 'error, salman needs to take a shower'
        return
      end

      # show the first hit
      a = movies[0][0]
      lookup_movie(m, a[1], 'http://www.boxofficemojo.com' + a[0])

    end

  end

  # return the actual boxoffice numbers from the given link
  def lookup_movie(m, title, link)

    html = fetchurl(link)
    if html.nil?
      debug "error fetching " + link
      return
    end

    numbers =  html.scan(/<td width="35%" align="right"><b>&nbsp;(.*?)(<\/b>)?<\/td>/)
    opening = html.scan(/<td align="center">Opening&nbsp;Weekend:<\/td><td><b>&nbsp;(.*?)<\/b><\/td><\/tr>/)
    budget = html.scan(/<td>Production Budget: <b>(.*?)<\/b><\/td>/)

    if numbers.length == 3 then
      m.reply(sprintf('%s - %s Domestic (%s Opening), %s Total, Budget: %s', title, numbers[0][0], opening[0],numbers[2][0], budget[0]))
    elsif numbers.length >= 1 then
      m.reply(sprintf('%s - %s Domestic (%s Opening), Budget: %s', title, numbers[0][0], opening[0], budget[0]))
    end

  end

    # get weekly box office chart numbers
  def boxoffice_chart(m, params)

    begin
      html = fetchurl('http://www.imdb.com/boxoffice/')
    rescue => ex
      debug ex.inspect
      debug ex.backtrace.join("\n")
      return
    end

    row_scraper = Scraper.define do
      array :cols
      process "td", :cols => :text
      result :cols
    end

    table_scraper = Scraper.define do
      array :rows
      process "tr", :rows => row_scraper
      result :rows
    end

    chart_scraper = Scraper.define do
      array :table
      process_first "div#main table", :table => table_scraper
      result :table
    end

    ret = chart_scraper.scrape(html)
    rows = ret.first

    m.reply sprintf("Weekend box office")
    count = 0
    rows.each { |bo|

      # bo = ["1", "", "The Avengers (2012)", "$200M", "$200M", "1"]
      #      rank, nil, name, weekend gross, total gross, weeks on chart

      count += 1
      # rank. title - weekend (total)
      m.reply sprintf("%s. %s - %s (%s)", bo[0], strip_tags(bo[2]), bo[3], bo[4])

      break if count == 5
    }

  end

end

plugin = BoxOffficePlugin.new
plugin.map 'bo', :action => 'boxoffice_chart'
plugin.map 'boxoffice', :action => 'boxoffice_chart'

plugin.map 'bo *movie', :action => 'boxoffice_movie'
plugin.map 'boxoffice *movie', :action => 'boxoffice_movie'
