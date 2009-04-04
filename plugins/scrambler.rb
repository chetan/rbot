
# TODO: 
# warn near end of game
# scores update during game
# alltime scores
# win count

require 'jcode'
require 'pathname'

class Scrambler

    attr :active
    
    attr :current_word
    attr :current_word_rnd
    attr :current_word_t
    
    attr :current_hint
    attr :hints
    attr :hints_remaining
    
    attr :word_list
    attr :scores
    attr :leader
    attr :leader_points
    
    def initialize
        @active = false
    end
    
    def start_game(word_list = 'mixed', num_words = 20)
        @active = true
        @scores = {}
        @word_list = get_word_list(word_list, num_words)
        next_word()
    end
    
    def end_game
        @current_word = @current_word_t = @current_word_rnd = @current_hint = @hints = @hints_remaining = nil
        @active = false
    end
    
    def active?
        @active
    end
    
    def score(player)
        @scores[player]
    end
    
    # returns a descending list of players by score
    # [ [player,score], [player,score], ... ]
    def get_scores
        @scores.sort { |a,b| b[1] <=> a[1] }
    end
    
    def guess(player, str)
        #log sprintf("checking if `%s' == `%s'", str, @current_word)
        if @current_word == str then
            # winnar!
            # ugly: @scores[player] = @scores.has_key? player ? @scores[player] + 1 : 1
            add_point(player)
            next_word()
            return true
        else
            return false
        end
    end
    
    def add_point(player)
        # give him the point
        if @scores.has_key? player then
            @scores[player] += 1
        else
            @scores[player] = 1
        end
        old_leader = @leader
        cur_leader = get_scores()[0]
        if old_leader.nil? or old_leader.empty? or (old_leader != cur_leader[0] and @leader_points < cur_leader[1]) then
            # leader change!
            @leader = cur_leader
            @leader_points = cur_leader[1]
        end
    end
    
    def hint
        word = @current_word
        hint_size = 3
        hint_size = 4 if word.length >= 10
        hint_size = 5 if word.length >= 20
        if @hints.nil? or @hints.empty? then
            @hints = []
            (0..word.length).each { |i| @hints << i if word[i,1] == ' ' }
            @hints.push( 0, word.length, (word.length / 2).round )
        else
            # get 3 more hints, if available
            @hints_remaining.shuffle[0, hint_size].each { |h| @hints << h }
        end
        hint = ''
        (0..word.length).each { |i|
            if @hints.include? i then
                hint += word[i,1]
            else
                hint += '_'
                @hints_remaining << i
            end
        }
        hint
    end
    
    def skip_word
        next_word()
    end
    
    # --- END PUBLIC INTERFACE --- #
    
    private
    
    def next_word
        return end_game() if @word_list.empty?
        @current_word = @word_list.pop
        @current_word_t = Time.new
        @current_word_rnd = shuffle_chars(@current_word)
        @current_hint = nil
        @hints = @hints_remaining = []
    end
    
    # get a randomized word list by name.
    # 'mixed' for a combination of all available lists
    def get_word_list(list = 'mixed', num_words = 20)
        filename = File.expand_path( File.dirname(__FILE__) ) + "/scrambler_" + list + ".txt"
        raise "list not found" if not File.exist? filename
        words = File.new(filename).readlines.map! { |w| w.strip }.map { |w| w.downcase if not w.empty? }
        return words.shuffle[0, num_words]
    end
    
    # shuffle a string
    def shuffle_chars(str)
        s = str.dup
        sz = s.length
        (0...sz).each { |j| 
            i = rand(sz-j)
            s[j], s[j+i] = s[j+i], s[j]
        }
        s
    end

end

class ScramblerPlugin < Plugin

    attr :games

    def initialize
        super
        @games = {}
    end
    
    def listen(m)
    
        return unless m.respond_to?(:public?) and m.public?
        return unless @games.has_key? m.channel and @games[m.channel].active?
        
        # active game, looking for guesses
        game = @games[m.channel]
        player = m.source
        guess = m.plainmessage.strip
        #log sprintf("player `%s' guessed `%s'", player, guess)
        leader = game.leader
        if game.guess(player, guess) then
            # got it!
            str = sprintf( "%s guessed correctly with `%s'.", player, guess )
            if leader != game.leader then
                str += sprintf(" they've taken the lead with %s points!", game.leader_points)
            else
                str += sprintf( " they now have %s points", game.score(player) )
            end
            m.reply str
            next_word(m, game)
        end
                    
    end
    
    def do_start(m, params)
        return do_word(m, params, "game already in progress!") if @games.has_key? m.channel and @games[m.channel].active?
        @games[m.channel] = game = Scrambler.new
        game.start_game(params[:word_list], params[:num_words].to_i)
        next_word(m, game)
    end
    
    def do_end(m, params)
        return m.reply "no game in progress!" if not @games.has_key? m.channel
        m.reply "the game has been ended :("
        game = @games[m.channel]
        game.end_game
        end_game(m, game)
    end
    
    def do_scores(m, params)
        return m.reply "no game in progress!" if not @games.has_key? m.channel
        game = @games[m.channel]
        show_scores(m, game)
    end
    
    def do_stats(m, params)
    
    end
    
    def do_skip(m, params)
        return m.reply "no game in progress!" if not @games.has_key? m.channel
        game = @games[m.channel]
        game.skip_word
        next_word(m, game)
    end
    
    def do_hint(m, params)
        return m.reply "no game in progress!" if not @games.has_key? m.channel
        game = @games[m.channel]
        m.reply "hint: " + game.hint
    end
    
    def do_word(m, params, extra = '')
        return m.reply "no game in progress!" if not @games.has_key? m.channel
        game = @games[m.channel]
        m.reply extra + "current word: " + game.current_word_rnd
    end
    
    def do_list(m, params)
        lists = []
        path = File.expand_path( File.dirname(__FILE__) )
        Pathname.new(path).each_entry { |e| lists << $1 if e.to_s =~ /scrambler_(.*)\.txt/ }
        m.reply "available word lists: " + lists.sort.join(', ')
    end
    
    # private methods
    
    def next_word(m, game)
        if not game.active? then
            # ran out of words
            m.reply "that was the last word!"
            return end_game(m, game)
        end            
        m.reply "new word: " + game.current_word_rnd
    end
    
    def end_game(m, game)
        scores = game.get_scores
        return if scores.empty?            
        winner = scores[0]
        m.reply sprintf("%s won with %s points!", winner[0], winner[1])
        show_scores(m, game)
    end
    
    def show_scores(m, game)
        scores = game.get_scores
        scores.collect! { |s| sprintf("%s: %s", s[0], s[1]) }
        m.reply scores.join(', ')
    end

end

pg = ScramblerPlugin.new

pg.map 'scrambler [:word_list] [:num_words]', :private => false, 
       :action => :do_start, 
       :defaults => { :word_list => 'mixed', :num_words => 20 }, 
       :requirements => { :num_words => %r|\d+| }
              
pg.map 'sc end', :private => false, :action => :do_end
pg.map 'sc scores', :private => false, :action => :do_scores
pg.map 'sc stats', :private => false, :action => :do_stats
pg.map 'sc skip', :private => false, :action => :do_skip
pg.map 'sc hint', :private => false, :action => :do_hint
pg.map 'sc word', :private => false, :action => :do_word
pg.map 'sc lists', :private => false, :action => :do_list

pg.map 'sc [:word_list] [:num_words]', :private => false, 
       :action => :do_start, 
       :defaults => { :word_list => 'mixed', :num_words => 20 }, 
       :requirements => { :num_words => %r|\d+| }
