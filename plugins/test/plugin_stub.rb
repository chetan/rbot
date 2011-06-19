
if RUBY_PLATFORM =~ /darwin/ then
    # fix for scrapi on Mac OS X
    require "rubygems"
    require "tidy"
    Tidy.path = "/usr/lib/libtidy.dylib"
end

require 'rubygems'
require 'scrapi'
require 'yaml'
require 'htmlentities'
require 'ostruct'

class Array

    def to_perly_hash()
        h = {}
        self.each_index { |i| g
            next if i % 2 != 0
            h[ self[i] ] = self[i+1]
        }
        return h
    end

end

module PluginMethods

def strip_tags(html)

        HTMLEntities.new.decode(
                html.gsub(/<.+?>/,'').
                gsub(/<br *\/>/m, '')
        )

end

def fetchurl(url)

    puts "< fetching: #{url}"

    uri = url.kind_of?(String) ? URI.parse(URI.escape(url)) : url
    http = Net::HTTP.new(uri.host, uri.port)
    http.start do |http|
        req = Net::HTTP::Get.new(uri.path + '?' + (uri.query || ''), {"User-Agent" => "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.0.10) Gecko/2009042315 Firefox/3.0.10"})
        res = http.request(req)
        if res.key?('location') then
            puts "< following redir: " + res['location']
            return fetchurl(URI.join(uri.to_s, res['location']))
        end
        return res.body
    end

end

# alternate to fetchurl() above
def f(url)
    uri = URI.parse(URI.escape(url))
    res = Net::HTTP.start(uri.host, uri.port) {|http|
      http.get(uri.path + '?' + uri.query)
    }
    return res.body
end

def strip_html_entities(str)
    str.gsub!(/&nbsp;/, ' ')
    str.gsub!(/&[#0-9a-z]+;/, '')
    str
end


def cleanup_html(str, strip_entities = false)
    str.gsub!(/&nbsp;/, '')
    str = strip_html_entities(str) if strip_entities
    str = strip_tags(str)
    str.strip!
    str.squeeze!(" \n\r")
    return str
end

end

class Plugin
    def map(*args)
    end
    def debug(msg)
        puts "DEBUG: #{msg}"
    end
    def log(msg)
        puts "INFO: #{msg}"
    end
    def warn(msg)
        puts "WARN: #{msg}"
    end
    def error(msg)
        puts "ERROR: #{msg}"
    end
    def registry=(obj)
        @registry = obj
    end
end

class Msg
    def reply(str)
        puts "reply: #{str}"
    end
    def sourcenick
        "crown"
    end
    def sourceaddress
        "freetibet@lando.pixelcop.org"
    end
end

$: << File.join(File.expand_path(".."))

def load_plugin(file)
    require(file)
    File.open(File.join(File.expand_path(".."), "#{file}.rb")).readlines.each{ |l|
        if l =~ /^class (.+?) </ then
           Kernel.const_get($1).class_exec {
              include PluginMethods
           }
           plugin = Kernel.const_get($1).new
           plugin.registry = {}
           return plugin
        end
    }
end
