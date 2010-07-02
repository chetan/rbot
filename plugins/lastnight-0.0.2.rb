#-- vim:sw=2:et
#++
#
# :title: Texts from Last Night for rbot
#
# Author:: Paul Dwerryhouse <paul@dwerryhouse.com.au>
# License:: GPL v2
# Homepage:: http://leapster.org/software/lastnight/
#
# Adapted from Mark Kretschmann and Casey Link's Grouphug.rb


class LastNightPlugin < Plugin
  REG  = Regexp.new('<description>(.*?)&lt;p&gt;&lt;a href', Regexp::MULTILINE)

  def initialize
    super
    @texts = Array.new
  end

  def help( plugin, topic="" )
    return _("LastNight plugin. Usage: 'lastnight' for random text.")
  end

  def lastnight(m, params)
    opts = { :cache => false }
    begin
        if @texts.empty?
          data = @bot.httputil.get("http://www.textsfromlastnight.com/feed/", opts)
          res = data.scan(REG)
          res.each do |quote|
            @texts << quote[0].ircify_html
          end
        end
        text = @texts.pop
        m.reply text

    rescue
      m.reply "failed to connect to textsfromlastnight.com"
    end
  end
end


plugin = LastNightPlugin.new

plugin.default_auth('create', false)

plugin.map "lastnight [:num]",
  :thread => true, :action => :lastnight, :requirements => { :num => /\d+/ }
