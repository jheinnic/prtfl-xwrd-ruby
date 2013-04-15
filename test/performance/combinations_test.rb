require 'test_helper'

class CombinationsTest < ActionDispatch::PerformanceTest
  # Refer to the documentation for all available options
  self.profile_options = { :runs => 5, :metrics => [:wall_time, :memory],
                           :output => 'tmp/performance', :formats => [:flat] }
  fixtures :word_items, :crosswords
  
  LETTERS_PRESENT_PER_TICKET = 18
  LETTERS_ABSENT_PER_TICKET = 8
  FINAL_KNOWN_LETTER_INDEX = 17
  ALPHABET = 
    ['a', 'b' ,'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',  
     'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z']

  def setup
    @num_unknowns = 10
    @known_letters = ['a', 'd', 'i', 'k', 'o', 'q', 't', 'y']
    @unused_letters = ['b', 'c', 'e', 'f', 'g', 'h', 'j', 'l', 'm', 'n', 'p', 'r', 's', 'u', 'v', 'w', 'x', 'z']
    
    @sample_xw = crosswords(:print_ticket)
  end
  
  def test_custom_helper
    @next_ticket = Array.new(LETTERS_PRESENT_PER_TICKET)

    (@num_unknowns..FINAL_KNOWN_LETTER_INDEX).each { |i| 
      @next_ticket[i] = @known_letters[LETTERS_PRESENT_PER_TICKET-i-1] }
    (0..(@num_unknowns-1)).each { |i|
      @next_ticket[i] = @unused_letters[LETTERS_ABSENT_PER_TICKET+i] }

    # CollectionTwiddler only manipulates the first K values of next_ticket,
    # and expects them to be populated with the last K values of unusedLetters.
    # K is equal to the number of unknown letters.  The remainder of the 18]
    # total letters used came from the record's persistent letter set. 
    permuteEngine = 
      ApplicationHelper::CollectionTwiddler.new(@next_ticket, @unused_letters, @num_unknowns)

    @num_combos = 1        
    while permuteEngine.next do
      @num_combos += 1
    end
  end

  def test_builtin_enumerator
    # CollectionTwiddler only manipulates the first K values of next_ticket,
    # and expects them to be populated with the last K values of unusedLetters.
    # K is equal to the number of unknown letters.  The remainder of the 18]
    # total letters used came from the record's persistent letter set. 
    permuteEngine = @unused_letters.combination(10)

    readMore = true
    @num_combos = 1 
    while(readMore) do
      begin
        @next_ticket = permuteEngine.next()
        @num_combos += 1
      rescue StopIteration
        return
      end
    end
  end
  
  def test_builtin_withblock
    @num_combos = 1        
    permuteEngine = @unused_letters.combination(10)  
    @unused_letters.combination(10) { |next_ticket| @next_ticket = next_ticket; @num_combos += 1; }
  end
  
  def test_calculate
    @sample_xw.recalculate()
  end
end