module CrosswordsHelper
  class WordFinder
    attr_reader :words

    def initialize board
      @board = board.slice(0..121)
      @rows = @board.scan(/.........../)
      @cols = (0..10).collect { |i| @rows.collect { |r| r[i] }.join('') }
      @runs = @rows + @cols
      @words = @runs.collect { |r| r.squeeze('-').split('-').select {|w| w.length > 1}}.flatten
      puts @words
    end
  end
end
