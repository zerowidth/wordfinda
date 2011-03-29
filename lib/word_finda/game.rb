module WordFinda
  class Game

    attr_reader :cache, :key
    attr_reader :data

    def initialize(cache, key)
      @cache, @key = cache, key
      unless @data = cache.get(key)
        @data = {
          :state => :waiting, # :starting :in_progress :voting :results
          :state_expires => nil,
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
        add_command :game_waiting
      end
      update_state
    end

    def save
      cache.set(key, @data, 1800) # expire in 30 minutes
    end

    def destroy
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
        # start_voting
        show_results
      end
    end

    def process_command(cmd, player_id)
      case cmd["command"]
      when "start_game"
        wait_for_start
      when "submit_word"
        submit_word_for_player(cmd["word"].downcase.strip, player_id)
      else
        puts "unknown command: #{cmd.inspect}"
      end
    end

    def wait_for_start
      if state == :waiting
        now = Time.now
        @data[:state] = :starting
        add_command :game_starting, :expires => now + 5
      end
    end

    def start_game
      @data[:state] = :in_progress
      board = @data[:board] = Board.generate.map { |c| c.capitalize }
      expires = Time.now + 10 # 180
      add_command :game_begin, :expires => expires, :board => board
    end

    def submit_word_for_player(word, player_id)
      if state == :in_progress && word.size > 3 && board.include?(word)
        add_command :accept_word, :word => word, :player_id => player_id
      else
        add_command :reject_word, :word => word, :player_id => player_id
      end
    end

    def start_voting
      @data[:state] = :voting
      add_command :game_vote, :board => board.board.map { |c| c.capitalize }
    end

    def show_results
      @data[:state] = :results
      add_command :game_results, :board => board.board.map { |c| c.capitalize }
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

    def board
      Board.new @data[:board].map { |c| c.downcase }
    end

    def add_command(name, data={})
      commands << [name, data]
    end

    def commands
      @data[:commands]
    end

    def latest_game_state
      commands.reverse.detect do |command|
        command.first.to_s.start_with?("game_")
      end
    end

    def player_join(name, id)
      unless players[id]
        players[id] = name
        player_words[id] = {
          :submitted => [],
          :accepted => [],
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

      latest = converted.reverse.detect { |cmd| cmd[:cmd].to_s.start_with?("game_") }

      return converted.delete_if do |cmd|
        (cmd[:cmd].to_s.start_with?("game_") && cmd != latest) ||
        (last && last <= converted.size && cmd[:seq] <= last) ||
        (cmd[:player_id] && cmd[:player_id] != player_id)
      end
    end

  end
end
