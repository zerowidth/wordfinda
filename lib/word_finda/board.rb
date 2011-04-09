module WordFinda

  class Board

    CUBES = [ # for a 5x5 game
      %w{f y i p r s},
      %w{p t e l c i},
      %w{o n d l r h},
      %w{h h d l o r},
      %w{r o r v g w},
      %w{m e e e e a},
      %w{a e a e e e},
      %w{a a a f s r},
      %w{t c n e c s},
      %w{s a f r a i},
      %w{c r s i t e},
      %w{i i t e i t},
      %w{o n t d d h},
      %w{m a n n g e},
      %w{t o t t e m},
      %w{h o r d n l},
      %w{d e a n n n},
      %w{t o o o t u},
      %w{b k j x qu z},
      %w{c e t l i i},
      %w{s a r i f y},
      %w{r i r p y r},
      %w{u e g m a e},
      %w{s s s n e u},
      %w{n o o w t u}
    ]
    # ADVANCEDCUBE = %w{qu m l k u i}

    def self.generate
      cubes = CUBES.dup
      board = []
      srand(rand(100000))
      while cubes.size > 0 do
        cube = cubes.delete_at(rand(cubes.size-1))
        board.push cube[rand(6)]
      end
      board
    end

    attr_reader :board

    def initialize(board)
      @board = board
    end

    def include?(word)
      find_word word_to_array(word)
    end

    # ----- board search -----

    # recursive search:
    def find_word(word_array, visited=[], location=nil)
      # recursion end condition
      return true if word_array.size == 0 # easy case, empty words exist everywhere!

      cube = word_array.shift # get the first letter on the list

      locations = find_cube(cube, visited, location) # potential search locations

      found = false
      locations.each do |location|
        new_word = word_array.dup
        new_visited = visited.dup
        new_visited[location] = true
        found ||= find_word(new_word, new_visited, location) # recursive call
      end

      return found
    end

    def find_cube(cube, visited, adjacent_to)
      found = []
      @board.each_with_index do |val, key|
        found << key if val == cube && !visited[key] && adjacent?(key, adjacent_to)
      end
      found
    end

    def adjacent? (key1, key2)
      return true unless key1 && key2 # any key is adjacent to nothingness! (nil)
      # do the search for key2 around key1 in a square grid
      key1x = key1 % 5 # get the x position in the grid
      key1y = (key1-key1x) / 5 # and the y position
      key2x = key2 % 5 # x position of second key
      key2y = (key2-key2x) / 5 # y position of second key
      # if the key x/y positions are within 1 of each other, then key2 is
      # in one of the 9 positions surrounding key1 (does not wrap!)
      (key1x-key2x).abs <= 1 && (key1y-key2y).abs <= 1
    end

    # 'q' is last to handle the case where words like valqqqid were recognized
    # as "v a l i d". This returns the q's, which don't exist in the board, and thus
    # the word will be rejected.
    # String#scan does the expected thing with the regex, so the qu matches first.
    def word_to_array(word)
      word.downcase.scan /[a-pr-z]|qu|q/
    end

  end

end

