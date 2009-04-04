
require 'htmlentities'

_lib = File.expand_path( File.dirname(__FILE__) )
$: << _lib if not $:.include? _lib

_lib = File.expand_path( File.dirname(__FILE__) + '/lib' )
$: << _lib if not $:.include? _lib

module PluginLib

    OUR_UNSAFE = Regexp.new("[^#{URI::PATTERN::UNRESERVED}#{URI::PATTERN::RESERVED}%# ]", false, 'N')
    
    Config.register Config::StringValue.new('pixelcop.db.host',
                                            :default => 'localhost',
                                            :desc => "MySQL DB hostname or IP")

    Config.register Config::StringValue.new('pixelcop.db.name',
                                            :default => 'rbot',
                                            :desc => "MySQL DB name")
                                            
    Config.register Config::StringValue.new('pixelcop.db.user',
                                            :default => 'rbot',
                                            :desc => "MySQL DB username")
                                            
    Config.register Config::StringValue.new('pixelcop.db.pass',
                                            :default => 'rbot',
                                            :desc => "MySQL DB password")
    
    def extract_urls(m)
    
        escaped = URI.escape(m.message, OUR_UNSAFE)
        URI.extract(escaped, ['http', 'https'])
    
    end
    
    def connect_db    
        host = @bot.config['pixelcop.db.host']
        name = @bot.config['pixelcop.db.name']
        user = @bot.config['pixelcop.db.user']
        pass = @bot.config['pixelcop.db.pass']

        str = sprintf('DBI:Mysql:database=%s;host=%s', name, host)
        return DBI.connect(str, user, pass)
    end

#     Schema used by save_url_in_db()
#   
#     CREATE TABLE `urls` (
#       `id` int(10) NOT NULL auto_increment,
#       `nick` varchar(255) default NULL,
#       `source` varchar(255) default NULL,
#       `url` varchar(255) default NULL,
#       `url_full` text,
#       `datetime` timestamp NOT NULL default CURRENT_TIMESTAMP,
#       `mirror` text,
#       PRIMARY KEY  (`id`)
#     ) ENGINE=MyISAM DEFAULT CHARSET=utf8;
    
    def save_url_in_db(url, orig_url = nil)

        begin
        
            dbh = connect_db()
            
            # don't insert of url already exists
            q = dbh.prepare('SELECT * from urls where url = ?')
            q.execute(url.url)
            return if q.rows() > 0
            
            query = dbh.prepare('INSERT into urls (nick, source, url, url_full, mirror) values (?, ?, ?, ?, ?)')
            query.execute(url.nick, url.channel, url.url, url.url, orig_url)
            dbh.disconnect
            
        rescue => ex
            error ex
            return
        end
  
    end

    def save_url_to_file(uri, filename)
    
        if not File.exist? filename then
            url = URI.parse(uri)
            req = Net::HTTP::Get.new(url.path)
            res = Net::HTTP.start(url.host, url.port) { |http|
                http.request(req)
            }
            open(filename, "wb") { |file|
                file.write(res.body)
            }
        end
    
    end

    def fetchurl(url, cache = true)
        
        url = URI.parse(URI.escape(url)) if not url.kind_of? URI
        
        for i in 1..3
            begin
                html = @bot.httputil.get(url, :cache => cache)
                return html
            rescue => ex
                error sprintf("failure #%d", i)
                error ex.inspect
                error ex.backtrace.join("\n")
                
            end
        end
        
    end
    
	def strip_tags(html)
		
		HTMLEntities.new.decode(
			html.gsub(/<.+?>/,'').
			gsub(/<br *\/>/m, '')
		)
		
	end
	
	# 		gsub(/&nbsp;/,' ').
	# 		gsub(/&amp;/,'&').
	# 		gsub(/&quot;/,'"').
	# 		gsub(/&lt;/,'<').
	# 		gsub(/&gt;/,'>').
	# 		gsub(/&ellip;/,'...').
	# 		gsub(/&apos;/, "'").
	#		gsub(/\r\n/, ' | ').
	
	def limit_output(str)
		str.strip[0, 1130]
	end
	
    def eastern_time()
        return TZInfo::Timezone.get('America/New_York').utc_to_local(Time.new)
    end

end
