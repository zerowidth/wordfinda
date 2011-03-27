module WordFinda
  class Game
    attr_reader :players
    attr_reader :player_words
    attr_reader :commands
    attr_reader :state

    def initialize
      @players = {}
      @player_words = Hash.new { |h,k| h[k] = [] }
      now = Time.now
      @commands = [
        [:game_waiting, {:started => now, :remaining => 10}]
      ]
      @state = :waiting # :in_progress, :voting, :results
    end

    def player_join(name, id)
      unless players[id]
        @commands << [:player_join, {:name => name, :id => id}]
        players[id] = name
      end
    end

    def player_commands(player_id, n = -1)
      commands.map.with_index do |command, i|
        cmd, data = command
        data.merge(:cmd => cmd, :seq => i)
      end
    end

  end
end
