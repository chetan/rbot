# wikipedia
# by chetan sarva <cs@pixelcop.net> 2008-04-07
#
# search wikipedia. similar to core 'search' plugin, but also gets article text.
# also includes a listener for grabbing text of pasted wikipedia links. 

require 'rubygems'
require 'json'
require 'net/http'
require 'uri/common'
require '0lib_rbot'

Net::HTTP.version_1_2

class WikiPediaPlugin < Plugin

	include PluginLib
	
	def help(plugin, topic="")
		return "wikipedia|wp <term>"
	end

	def lookup(m,params)

		if params[:query].length == 0
			m.reply 'incorrect usage: ' + help(m.plugin)
			return
		end
		
		s = params[:query].join(' ')
		
		url = google_search(s + " site:en.wikipedia.org")
		
		return m.reply "No entry found for #{s}" if not url
		
		#debug "got url: #{url}"
		
		# http://en.wikipedia.org/wiki/Java_(programming_language)
		url =~ %r|^http://[a-z]+.wikipedia.org/wiki/(.*)$|
        title = $1
        
        #debug "found title #{title}"
        
        begin
            m.reply "#{title}: " + shorten( title, get_article(title) )
        rescue
            m.reply $!
        end
		
	end
	
	def shorten(title, article)
	    
	    max_len = 1143 - (title.length + 2)
	    return article[0, max_len]
	    
	end
	
  def listen(m)
    
    return unless m.kind_of?(PrivMessage)

    if m.message =~ %r|http://en.wikipedia.org/wiki/([^ ]+)|
		# found a wikipedia link
        title = $1
        return if title =~ /^File:/
        begin
            m.reply "#{title}: " + shorten( title, get_article(title) )
        rescue
            m.reply $!
        end
    end

  end
	
  def google_search(str)
  
    searchfor = URI.escape str

    query = "/search?q=#{searchfor}&btnI=I%27m%20feeling%20lucky"
    result = "not found!"

    proxy_host = nil
    proxy_port = nil

    if(ENV['http_proxy'])
      if(ENV['http_proxy'] =~ /^http:\/\/(.+):(\d+)$/)
        proxy_host = $1
        proxy_port = $2
      end
    end

    http = @bot.httputil.get_proxy(URI.parse("http://www.google.com"))

    begin
      http.start {|http|
        resp = http.get(query)
        if resp.code == "302"
          result = resp['location']
        end
      }
    rescue => e
      p e
      if e.response && e.response['location']
        result = e.response['location']
      else
        result = "error!"
      end
    end
    
    return result
  
  end
	
	def get_article(title)
	
	    wp = 'http://en.wikipedia.org/w/index.php?title=%s&action=raw&section=0'
	    
        res = fetchurl(sprintf(wp, title))
        raise sprintf('Lookup failed for "%s"', title) if not res
        
        if res =~ /^#REDIRECT \[\[(.*)\]\]/i then
            title = $1
            res = fetchurl(sprintf(wp, title))
            raise sprintf('Lookup failed for "%s"', title) if not res
        end
        
        debug res
        
        m = res.match(/^\{\{ *infobox.*^\}\}(.*)/mi) 
        if m 
            entry = m[1]
        else 
            entry = res
        end
        
        if entry =~ %r|<title>Error</title>| or entry =~ %r|<title>Error</title>| then
            return 'Error fetching entry'
        end

        text = strip_tags( parse(entry) ).
        	   gsub(/\r\n/, ' | ').
               gsub(/[\n\r]/, ' ').
               strip
        
        return text
	
	end
	
	def parse(raw)
	
	    scanner = StringScanner.new(raw)
	    cursor = 0
	    categories = Array.new
	    languages = Hash.new
	    fulltext = ''
	    related = Array.new
	    headings = Array.new
	    text = ''
        seen_heading = false
        
        while cursor < raw.length do
        
            scanner.pos = cursor
    
            ## [[ ... ]]
            
            if (substr = scanner.scan(/\G\[\[ *(.*?) *\]\]/)) and substr =~ /\G\[\[ *(.*?) *\]\]/ then
                directive = $1
                cursor += $&.length - 1
                if directive =~ /\:/ then
                    (type, text) = directive.split(':')
                    if type.downcase == 'category' then
                        categories << text
                    end
    
                    # language codes
                    if type.length == 2 and type.downcase == type then
                        languages[type] = Array.new if not languages[type]
                        languages[type] = text
                    end
                
                elsif directive =~ /\|/ then
                    (lookup, name) = directive.split('|')
                    fulltext += name
                    related << lookup if lookup !~ /^#/
               
                else
                    fulltext += directive
                    related << directive
                end
  
            ## === heading 2 ===
            elsif (substr = scanner.scan(/=== *(.*?) *===/)) and substr =~ /=== *(.*?) *===/ then
                ### don't bother storing these headings
                fulltext += $1
                cursor += $&.length - 1
                next
    
            ## == heading 1 ==
            elsif (substr = scanner.scan(/== *(.*?) *==/)) and substr =~ /== *(.*?) *==/ then
                headings << $1
                text = fulltext if not seen_heading
                seen_heading = true
                fulltext += $1
                cursor += $&.length - 1
                next
    
            ## '' italics '' or ''' bold '''
            elsif (substr = scanner.scan(/''' *(.*?) *'''/)) and substr =~ /''' *(.*?) *'''/ then
                fulltext += $1
                cursor += $&.length
                next
    
            ## {{ disambig }}
            elsif (substr = scanner.scan(/\{\{ *(.*?) *\}\}/)) and substr =~ /\{\{ *(.*?) *\}\}/ then
                ## ignore for now
                cursor += $&.length
                next
    
            else
                fulltext += raw[cursor,1]
            
            end
        
            cursor += 1
        
        end
        
        return fulltext
	
	end
		
end 

plugin = WikiPediaPlugin.new
plugin.register("wikipedia")
plugin.map 'wikipedia *query', :action => 'lookup'
plugin.map 'wiki *query', :action => 'lookup'
