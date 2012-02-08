# old!
# by chetan sarva <cs@pixelcop.net> 2008-09-11
#
# never forget! don't paste old links, bitch!@

class OldNewsPlugin < Plugin

  def say_old(m, params)

    # http://www.pixelcop.org/~chetan/files/jpg/old.jpg
    # http://is.gd/2vj6
    m.reply "nicca that's so old!  http://is.gd/2vj6"

  end

    def say_sad(m, params)
        m.reply"sad panda :(  http://www.sadtrombone.com/"
    end

    def say_zero(m, params)
        m.reply "this is how much I care: http://fw2.org/eomi0w"
    end

    def say_kobe(m, params)
        m.reply "http://www.pixelcop.org/~chetan/pics/kobe.jpg"
    end

    def say_np(m, params)
        m.reply "no problemo http://www.pixelcop.org/~chetan/pics/youre_welcome.jpg"
    end

    def say_yes(m, params)
        m.reply "YES! http://www.pixelcop.org/~chetan/pics/YES.jpg"
    end

    def say_notbad(m, params)
        m.reply "notbad.jpg http://bit.ly/notbad"
    end

end

plugin = OldNewsPlugin.new
plugin.map 'old',  :action   => 'say_old'
plugin.map 'sad',  :action   => 'say_sad'
plugin.map 'zero', :action   => 'say_zero'
plugin.map 'care', :action   => 'say_zero'
plugin.map 'kobe', :action   => 'say_kobe'
plugin.map 'np',   :action   => 'say_np'
plugin.map 'yes',  :action   => 'say_yes'
plugin.map 'notbad', :action => 'say_notbad'
plugin.map 'nb',   :action   => 'say_notbad'
