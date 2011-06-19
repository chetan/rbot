# rotten tomatoes
# by chetan sarva <cs@pixelcop.net> 2007-01-23
#
# if given a movie title, finds the rating for that movie, or
# displays ratings for movies opening this week

require 'rexml/document'
require 'uri/common'
require '0lib_rbot'
require 'scrapi'
require 'ostruct'
require 'time'

Struct.new("Movie", :title, :link, :percent, :rating, :desc, :count, :fresh, :rotten, :release)

class RottenPlugin < Plugin

    include REXML
    include PluginLib

    def initialize
        super
        @rss = "http://i.rottentomatoes.com/syndication/rss/"
        @search = "http://www.rottentomatoes.com/search/full_search.php?search="
        @site = "http://www.rottentomatoes.com"
    end

    def help(plugin, topic="")
        return "rotten|rt [num] [opening|upcoming|top|current|<movie title>] => ratings for movies opening this week, rt top => ratings for the current top movies, rt upcoming => advance ratings for upcoming movies, rt current => top recent releases, rt <movie title> => lookup rating for a movie"
    end

    def do_rotten(m, params)

        num = params[:num].to_i if params[:num]

        movie = params[:movie]
        movie = movie.join(" ").downcase if not movie.nil?

        if movie.nil? or movie.length == 0 or movie == 'opening' or movie == 'new'
            opening m, params, @rss + "opening.xml", num
        elsif movie == 'upcoming'
            opening m, params, @rss + "upcoming.xml"
        elsif movie == 'top'
            opening m, params, @rss + "top_movies.xml"
        elsif movie == 'current'
            opening m, params, @rss + "in_theaters.xml"
        else
            search m, params, movie
        end

    end

    def search(m, params, movie)

        info = nil

        # first, search in the complete xml feed to see if its a current movie
        begin
            info = search_xml(m, movie)
        rescue => ex
            m.reply "xml search failed: #{ex}"
            error ([ex.to_s] + ex.backtrace).join("\n")
        end

        # try searching the site
        begin
            info = search_site(m, movie) if info.nil?
        rescue => ex
            m.reply "site search failed: #{ex}"
            error ([ex.to_s] + ex.backtrace).join("\n")
        end

        # couldn't find anything
        return m.reply(sprintf("`%s' not found", movie)) if info.nil?

        if info.fresh == 0 and info.total == 0 and info.release_date and info.release_date > Time.new then
            # zero ratings and is in the future
            return m.reply(sprintf("%s - %s (no reviews) %s", info.title, info.release_date.strftime("%b %d, %Y"), info.link))
        end

        m.reply(sprintf("%s - %s%% = %s (%s/%s) %s", info.title, info.rating, info.status, info.fresh, info.total, info.link))

    end

    def search_xml(m, movie)
        r = search_xml_feed("#{@rss}complete_movies.xml", m, movie)
        r = search_xml_feed("#{@rss}opening.xml", m, movie) if not r
        return r
    end

    def search_xml_feed(feed_url, m, movie)

        xml = fetchurl(feed_url)
        unless xml
            warn "faild to fetch feed #{feed_url}"
            return nil
        end

        doc = Document.new xml
        unless doc
            m.reply "invalid xml returned from #{feed_url}"
            return nil
        end

        begin

            title = percent = rating = link = desc = release = nil
            doc.elements.each("rss/channel/item") {|e|

                title = e.elements["title"].text.strip
                link = e.elements["link"].text

                if not e.elements["RTmovie:tomatometer_percent"].text.nil?
                    # movie has a rating
                    title = title.slice(title.index(' ')+1, title.length) if title.include? '%'
                end

                if title.downcase == movie or title.downcase.include? movie
                    return get_movie_info(m, title, link)
                end

            }

        rescue => ex
            error ex.inspect
            error ex.backtrace.join("\n")
        end

        return nil
    end

    def search_site(m, movie)

        # second, try searching for the movie title
        html = fetchurl(@search + movie)

        movie_scraper = Scraper.define do

            process "li h3", :title => :text
            process "li h3 a", :url => "@href"
            process "li span.tMeterScore", :score => :text

            result :title, :url, :score
        end

        movies_scraper = Scraper.define do

            array :movies
            process "ul#movie_results_ul li", :movies => movie_scraper

            result :movies
        end

        movies = movies_scraper.scrape(html)

        movies.each { |_m|
            if _m.title.downcase == movie then
                return get_movie_info(m, _m.title, @site + _m.url)
            end
        }

        # no exact match, let's use the first result..
        return get_movie_info(m, movies[0].title, @site + movies[0].url)

    end

    def get_movie_info(m, title, link)

        html = fetchurl(link)
        if html.nil?
            debug "error fetching " + link
            return nil
        end

        movie_scraper = Scraper.define do

            array :info

            process "div#all-critics-numbers p.critic_stats", :ratings => :text
            process "div#all-critics-numbers span#all-critics-meter", :rating => :text
            process "div#top-critics-numbers span#all-critics-meter", :rating_top => :text
            process "div#movie_stats span", :info => :text

            result :ratings, :rating, :rating_top, :info

        end

        info = movie_scraper.scrape(html)

        movie_info = OpenStruct.new({:title => title,
                                     :rating => info.rating.to_i,
                                     :rating_top => info.rating_top.to_i,
                                     :link => link })

        if info.ratings then
            if info.ratings.match(/Reviews Counted: ?(\d+)/) then
                movie_info.total = $1.to_i
            end

            if info.ratings.match(/Fresh: ?(\d+)/) then
                movie_info.fresh = $1.to_i
            end

            if info.ratings.match(/Rotten: ?(\d+)/) then
                movie_info.rotten = $1.to_i
            end

            if info.ratings.match(/Average Rating: ?(.*)/) then
                movie_info.average = $1
            end
        else
            movie_info.total = movie_info.fresh = movie_info.rotten = movie_info.average = 0
        end

        # pull out stats
        if info.info then
            movie_stats = info.info.to_perly_hash
            movie_info.runtime      = movie_stats['Runtime:']
            movie_info.release_date = movie_stats['Theatrical Release:']
            movie_info.box_office   = movie_stats['Box Office:']
            movie_info.rated        = movie_stats['Rated:']
            movie_info.genre        = movie_stats['Genre:']
        end

        # cleanup release date
        if movie_info.release_date then
            begin
                rd = movie_info.release_date.split(' ')[0..2].join(' ')
                movie_info.release_date = Time.parse(rd)
            rescue => ex
                error ([ex.to_s] + ex.backtrace).join("\n")
            end
        end


        # double check the rating
        begin
            r = (movie_info.fresh.to_f / movie_info.total * 100).round
        rescue => ex
            r = 0
        end
        movie_info.rating = r if r != movie_info.rating

        movie_info.status = movie_info.rating >= 60 ? 'Fresh' : 'Rotten'

        return movie_info
    end



    # print opening movies and their scores
    def opening(m, params, url, num = 5)

        num -= 1
        num = 0 if num < 0

        xml = fetchurl(url)
        unless xml
            m.reply "faild to fetch feed"
            return
        end

        begin
            doc = Document.new xml
        rescue => ex
            if xml.include? '<html>' then
                return m.reply("rottentomatoes rss feeds are currently down")
            else
                return m.reply("error parsing feed: " + ex)
            end
        end

        begin

        matches = Array.new
        doc.elements.each("rss/channel/item") {|e|

            title = e.elements["title"].text.strip

            if not e.elements["RTmovie:tomatometer_percent"].text.nil?
                # movie has a rating
                title = title.slice(title.index(' ')+1, title.length) if title.include? '%'
                percent = e.elements["RTmovie:tomatometer_percent"].text + "%"
                rating = e.elements["RTmovie:tomatometer_rating"].text
            else
                # not yet rated
                percent = "n/a"
                rating = ""
            end

            matches << sprintf("%s - %s %s", title, percent, rating).strip

        }

        rescue => ex
            error ex.inspect
            error ex.backtrace.join("\n")

        end

        (0..num).each { |i|
            m.reply matches[i] if matches[i]
            break if i == matches.size
        }

    end

end

plugin = RottenPlugin.new
plugin.map 'rotten [:num] *movie', :action => 'do_rotten', :defaults => { :movie => nil, :num => 5 }, :requirements => { :num => %r|\d+| }
plugin.map 'rt [:num] *movie',     :action => 'do_rotten', :defaults => { :movie => nil, :num => 5 }, :requirements => { :num => %r|\d+| }
