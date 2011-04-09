require "spec_helper"

describe WordFinda::Board do

  describe ".generate" do
    it "generates a random array representing a board" do
      WordFinda::Board.generate.should have(25).cubes
    end
  end

  context "when initialized with a board" do
    before :each do
      @board = WordFinda::Board.new %w{
        i e a d r
        s z n e d
        n r o a c
        a u e e s
        p a d o o
      }
    end

    it "includes 'seed'" do
      @board.should include("seed")
    end

    it "includes 'dread'" do
      @board.should include("dread")
    end

    it "does not include 'sneer'" do
      @board.should_not include("sneer")
    end

    it "does not include 'seedqqq'" do
      @board.should_not include("seedqqq")
    end

  end
end
