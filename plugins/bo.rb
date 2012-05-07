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
    html = fetchurl('http://www.boxofficemojo.com/search/?q=' + movie)

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

    search_scraper = Scraper.define do
      array :table
      process "div#body table:nth-child(5)", :table => table_scraper
      result :table
    end

    ret = search_scraper.scrape(html)
    rows = ret.first

    # verify we got the right table/data
    begin
      if rows.first.first.downcase !~ /^movie title/ then
        raise "bad data"
      end
      rows.shift # discart first row
    rescue Exception => ex
      # will raise on nil, etc as well
      m.reply "error parsing data"
      return
    end

    # look for exact match first
    found = nil
    rows.each do |row|
      if row.first.strip.downcase == movie then
        found = row
      end
    end

    # take first match if none found
    match = found || rows.first

    # [0] "Movie Title (click title to view)",
    # [1] "Studio",
    # [2] "Lifetime Gross
    # [3] Theaters",
    # [4] "Opening
    # [5] Theaters",
    # [6] "Release",
    # [7] "Links"

    m.reply sprintf("%s (%s) - %s Lifetime Gross / %s Opening", match.first.strip, match[6], match[2], match[4])

    # show list of other matches
    if found.nil? and rows.size > 1 then
      others = []
      rows.each do |row|
        if row.first != match.first then
          others << row.first.strip
        end
      end
      m.reply sprintf("Other matches: %s", others.join(", "))
    end

  end

    # if numbers.length == 3 then
    #   m.reply(sprintf('%s - %s Domestic (%s Opening), %s Total, Budget: %s', title, numbers[0][0], opening[0],numbers[2][0], budget[0]))
    # elsif numbers.length >= 1 then
    #   m.reply(sprintf('%s - %s Domestic (%s Opening), Budget: %s', title, numbers[0][0], opening[0], budget[0]))
    # end

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
