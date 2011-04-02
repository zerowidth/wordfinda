module WordFinda
  class Game

    WAIT_TIME = 10
    GAME_TIME = 180
    VOTE_TIME = 30

    attr_reader :cache, :key
    attr_reader :data

    def initialize(cache, key)
      @cache, @key = cache, key
      load_from_cache
      update_state
    end

    def load_from_cache
      unless @data = cache.get(key)
        reset
      end
    end

    def reset
      @data = {
        :state => :waiting, # :starting :in_progress :voting :results
        :commands => [],
        :players => {},
        :board => nil,
        :player_words => {},
        :voting => {
          :unknown => [],
          :accepted => [],
          :rejected => []
        }
      }
      add_command :reset
      add_command :game_waiting
    end

    def save
      cache.set(key, @data, 3600) # expire in 30 minutes
    end

    def destroy
      @data = nil
      cache.delete(key)
    end

    def update_state
      latest_command = latest_game_state

      return unless expiration = latest_command[1][:expires]
      return unless expiration < Time.now

      case state
      when :starting
        start_game
      when :in_progress
        start_voting
      when :voting
        check_for_next_vote true # expired!
      end
    end

    def process_command(cmd, player_id)
      puts "#{state.inspect} - #{cmd["command"]}"
      case cmd["command"]
      when "start_game"
        if state == :waiting
          wait_for_start
        elsif state == :results
          destroy
          reset
          wait_for_start
        end
      when "submit_word"
        submit_word_for_player(cmd["word"].downcase.strip, player_id)
      when "player_vote"
        submit_vote_for_player(cmd["word"], player_id, cmd["vote"] != "false")
      else
        puts "unknown command: #{cmd.inspect}"
      end
    end

    def wait_for_start
      if state == :waiting
        now = Time.now
        @data[:state] = :starting
        add_command :game_starting, :expires => now + WAIT_TIME
      end
    end

    def start_game
      @data[:state] = :in_progress
      board = @data[:board] = Board.generate.map { |c| c.capitalize }
      expires = Time.now + GAME_TIME
      add_command :game_begin, :expires => expires, :board => board
    end

    def submit_word_for_player(word, player_id)
      if state == :in_progress && word.size > 3 && board.include?(word)
        if Aspell.new.check(word)
          player_words[player_id][:accepted] << word
        else
          player_words[player_id][:require_vote] << word
        end
        add_command :accept_word, :word => word, :player_id => player_id
      else
        add_command :reject_word, :word => word, :player_id => player_id
      end
    end

    def submit_vote_for_player(word, player_id, vote)
      if word == voting[:unknown].first
        add_command :player_vote, :id => player_id, :word => word, :vote => vote
        check_for_next_vote
      else
        puts "wtf vote for word not yours"
      end
    end

    def start_voting

      # remove duplicates
      all_words = Hash.new { |h,k| h[k] = [] }
      player_words.each do |player_id, words|
        words[:accepted].each { |word| all_words[word] << player_id }
        words[:require_vote].each { |word| all_words[word] << player_id }
      end
      all_words.each do |word, players|
        if players.size > 1
          players.each do |player_id|
            player_words[player_id][:accepted].delete word
            player_words[player_id][:require_vote].delete word
            player_words[player_id][:duplicates] << word
          end
        end
      end

      if player_words.any? { |id, words| words[:require_vote].size > 0 }

        @data[:state] = :voting
        add_command :game_vote, :board => board.board.map { |c| c.capitalize }

        player_words.each do |player_id, words|
          if words.all? { |key, list| list.empty? }
            # sorry, this player can't vote, no words were submitted
            add_command :no_voting, :player_id => player_id
          else
            # let everyone know this player is allowed to participate
            add_command :player_voting, :id => player_id, :name => players[player_id]
            voting[:unknown].concat words[:require_vote]
          end
        end

        next_vote
      else

        show_results
      end
    end

    def voting_players
      player_words.reject do |player_id, words|
        words.all? { |key, list| list.empty? }
      end.map { |player_id, words| player_id }
    end

    def check_for_next_vote(expire_now = false)
      word = voting[:unknown].first
      votes = {:yes => [], :no => []}

      commands.select do |command|
        command.first == :player_vote && command.last[:word] == word
      end.each do |command|
        player_id = command.last[:id]
        if command.last[:vote]
          votes[:yes].push(player_id).uniq!
          votes[:no].delete player_id
        else
          votes[:no].push(player_id).uniq!
          votes[:yes].delete player_id
        end
      end

      whose_word = player_words.detect do |id, words|
        words[:require_vote].include?(word)
      end.first

      minimum_votes = voting_players.size / 2.0

      if expire_now
        if votes[:yes].size > votes[:no].size
          # accept
          player_words[whose_word][:require_vote].delete(word)
          player_words[whose_word][:accepted] << word
          voting[:accepted] << voting[:unknown].shift
          next_vote
        else
          # reject
          player_words[whose_word][:require_vote].delete(word)
          player_words[whose_word][:rejected] << word
          voting[:rejected] << voting[:unknown].shift
          next_vote
        end
      else
        if votes[:no].include?(whose_word) || votes[:no].size >= minimum_votes
          # reject
          player_words[whose_word][:require_vote].delete(word)
          player_words[whose_word][:rejected] << word
          voting[:rejected] << voting[:unknown].shift
          next_vote
        elsif votes[:yes].size > minimum_votes
          # accept
          player_words[whose_word][:require_vote].delete(word)
          player_words[whose_word][:accepted] << word
          voting[:accepted] << voting[:unknown].shift
          next_vote
        end
      end

    end

    def next_vote
      if voting[:unknown].first
        expires = Time.now + VOTE_TIME
        players_for_vote.each do |player_id|
          add_command :vote,
            :word => voting[:unknown].first,
            :player_id => player_id,
            :expires => expires
        end
      else
        # done voting
        show_results
      end
    end

    def show_results
      @data[:state] = :results

      results = []

      player_words.each do |player_id, words|
        score = words[:accepted].map { |w| score_for(w) }.inject(0) { |m,x| m + x }
        results << {
          :name => players[player_id],
          :score => score,
          :words => words
        }
      end

      add_command :game_results,
        :board => board.board.map { |c| c.capitalize },
        :results => results.sort_by {|r| -r[:score] } # reverse sort
    end

    def state
      @data[:state]
    end

    def players
      @data[:players]
    end

    def player_words
      @data[:player_words]
    end

    def players_for_vote
      player_words.select do |player_id, words|
        words.any? { |key, list| !list.empty? }
      end.map { |player_id, words| player_id }
    end

    def voting
      @data[:voting]
    end

    def board
      Board.new @data[:board].map { |c| c.downcase }
    end

    def add_command(name, data={})
      puts "adding command: #{name} #{data.inspect}"
      commands << [name, data]
    end

    def commands
      @data[:commands]
    end

    def latest_game_state
      commands.reverse.detect do |command|
        command.first.to_s.start_with?("game_") || command.first == :vote
      end
    end

    def player_join(name, id)
      unless players[id]
        players[id] = name
        player_words[id] = {
          :accepted => [],
          :require_vote => [],
          :rejected => [],
          :duplicates => []
        }
        add_command :player_join, :name => name, :id => id
      end
    end

    def commands_for_player(player_id, last=nil)
      converted = commands.map.with_index do |command, i|
        cmd, params = command
        params.merge(:cmd => cmd, :seq => i)
      end

      latest_game = converted.reverse.detect do |cmd|
        cmd[:cmd].to_s.start_with?("game_")
      end

      latest_vote = converted.reverse.detect do |cmd|
        cmd[:cmd] == :vote && cmd[:player_id] == player_id
      end

      return converted.delete_if do |cmd|
        # remove the reset command if the client's seen commands before,
        # but only if it's seen commands that are available.
        (last && last <= converted.size && cmd[:cmd] == "reset") ||

        # remove commands before than the last seen command, if applicable
        # ignore the last seen if the game has been reset, i.e. the
        # number of commands is less than the number the client claims to have seen.
        (last && last <= converted.size && cmd[:seq] <= last) ||

        # remove any game state commands except the latest one
        (cmd[:cmd].to_s.start_with?("game_") && cmd != latest_game) ||

        # remove vote commands that don't apply (on full reload)
        (latest_game[:cmd] != :game_vote && cmd[:cmd] == :vote) ||

        # remove any vote commands that aren't the latest one
        (latest_vote && cmd[:cmd] == :vote && cmd != latest_vote) ||

        # remove any player vote commands that are before the latest vote
        (latest_vote && cmd[:cmd] == :player_vote && cmd[:seq] < latest_vote[:seq]) ||

        # remove anything that has a player id that isn't for this player
        (cmd[:player_id] && cmd[:player_id] != player_id)
      end
    end

    def score_for(word)
      case word.length
      when 0..3
        0
      when 4
        1
      when 5
        2
      when 6
        3
      when 7
        5
      else
        11
      end
    end

  end
end
