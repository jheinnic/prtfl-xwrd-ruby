require 'benchmark'
require 'crossword'
require 'set'

class MockWordItem 
  def initialize(tv, tli)
    @text_value = tv
    @triple_letter_index = tli
  end

  def text_value()
    return @text_value
  end
  
  def triple_letter_index()
    return @triple_letter_index
  end
end

    
class MockCrossword 
  def initialize()
    @word_items = 
      [
        MockWordItem.new('resist', -1),    MockWordItem.new('diary', -1), 
        MockWordItem.new('mug', -1),       MockWordItem.new('solo', -1),
        MockWordItem.new('agency', -1),    MockWordItem.new('ant', -1), 
        MockWordItem.new('menu', -1),      MockWordItem.new('odd', -1),
        MockWordItem.new('aunt', -1),      MockWordItem.new('dim', 1), 
        MockWordItem.new('drift', 1),      MockWordItem.new('huge', 1),
        MockWordItem.new('battery', -1),   MockWordItem.new('jeopardy', 1),
        MockWordItem.new('atom', -1),      MockWordItem.new('swing', -1),
        MockWordItem.new('sprint', -1),    MockWordItem.new('dot', -1), 
        MockWordItem.new('rice', -1),      MockWordItem.new('sympathy', -1),
        MockWordItem.new('volunteer', -1), MockWordItem.new('auto', -1)
      ]
  end
  
  def bonus_word()
    return 'latch'
  end
  
  def bonus_value()
    return 2
  end
  
  def revealed()
    # return 'yuehwpivjzrsbfcnoa'
    # return 'yuehwpivjzrs'
    # return 'yuehwpivj'
    # return 'yuehwp'
    # return 'yue'
    # return ''

    return 'yuehwpi'
  end

  MOCK_BONUS_OFFSETS = [22, 44, 66, 88]
  MOCK_TRIPLE_MATCH_PAYOUT_OFFSET = 115;
  MOCK_PAYOUT_LOOKUP = [
    # No Bonus, No Triple
    0, 0, 1, 2, 3, 4, 7, 9, 11, 14, 16, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 
    # $4 Bonus, No Triple
    2, 2, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $5 Bonus, No Triple
    3, 3, 17, 17, 4, 6, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $10 Bonus, No Triple
    4, 4, 17, 17, 6, 7, 8, 10, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $30 Bonus, No Triple
    8, 8, 17, 17, 17, 17, 9, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # No Bonus, With Triple
    17, 0, 17, 5, 6, 8, 10, 12, 13, 15, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $4 Bonus, With Triple
    17, 2, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $5 Bonus, With Triple
    17, 3, 17, 17, 7, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $10 Bonus, With Triple
    17, 4, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 
    # $30 Bonus, No Triple
    17, 8, 17, 17, 17, 10, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17
  ]

  def self.word_to_bitfield(word = '') 
    val = 0
    word.codepoints { |cp| val = val | (1 << (cp-97)) }
    return val
  end

  def self.word_to_bitset(word = '') 
    val = Array[]
    word.codepoints { |cp| val = val << (1 << (cp-97)) }
    return val
  end

  MOCK_ALPHABET   = 'abcdefghijklmnopqrstuvwxyz'
  MOCK_ALPHAFIELD = word_to_bitfield(MOCK_ALPHABET)
  MOCK_ALPHASET   = word_to_bitset(MOCK_ALPHABET)

  MOCK_LETTERS_PRESENT_PER_TICKET = 18
  MOCK_LETTERS_ABSENT_PER_TICKET = 8
  MOCK_EMPTY_SET = Set[]

  def recalculate
    return unless win_criteria_defined?

    parse_letter_sets
    @payout_counters = Array.new(18, 0)
    @unused_bitset.combination(@num_unknowns) { |next_combination|
      calculate_payout_index(next_combination)
    }
  end

  def recount
    parse_letter_sets
    @unused_bitset.combination(@num_unknowns) { |next_combination| }
  end

  def reconsider
    parse_letter_sets
    @last_combination = Array.new
    @unused_bitset.combination(@num_unknowns) { |next_combination|
      added = next_combination - @last_combination
      dropped = @last_combination - next_combination
      @last_combination = next_combination
    }
  end

  def report
    parse_letter_sets
    @last_combination = Array.new
    @unused_bitset.combination(@num_unknowns) { |next_combination|
      added = next_combination - @last_combination
      dropped = @last_combination - next_combination
      @last_combination = next_combination

      puts "** Next :: #{next_combination.inspect}\n** Added :: #{added.inspect}\n** Minus :: #{dropped.inspect}\n\n"
    }
  end

  def win_criteria_defined?
    (bonus_value() > -1) and
    (bonus_value() < 4) and
    (bonus_word().length == 5) and
    (@word_items.size == 22) and
    (revealed != @last_calc_revealed) and
    (@word_items.select { |i| i.triple_letter_index() >= 0 }.size == 4)
  end

  private
  def parse_letter_sets
    known_letters   = revealed().nil? ? MOCK_EMPTY_SET : MockCrossword.word_to_bitset(revealed())
    @known_bitfield = MOCK_ALPHAFIELD & (~ MockCrossword.word_to_bitfield(revealed()))

    @num_unknowns   = MOCK_LETTERS_PRESENT_PER_TICKET - known_letters.size
    @unused_bitset  = MOCK_ALPHASET - known_letters

    @basic_words =
      @word_items.select { |wi| wi.triple_letter_index() == -1 }
    @triple_words = @word_items - @basic_words
    @basic_words.collect! { |wi| MockCrossword.word_to_bitfield(wi.text_value()) }
    @triple_words.collect! { |wi| MockCrossword.word_to_bitfield(wi.text_value()) }
    @bonus_bitfield = MockCrossword.word_to_bitfield(bonus_word())
  end

  def calculate_payout_index(hypothesis)
    coverage = payout_offset = triple_offset = 0

    hypothesis.each { |next_guess| coverage = (coverage | next_guess) }
    coverage = @known_bitfield & (~ coverage)

    @basic_words.each { |word|
      payout_offset += 1 if ((word & coverage) == 0) }
    @triple_words.each { |word|
      if ((word & coverage) == 0) then
        payout_offset += 1;
        triple_offset = MOCK_TRIPLE_MATCH_PAYOUT_OFFSET;
      end
    }
    payout_offset += triple_offset
    
    if ((@bonus_bitfield & coverage) == 0) then
      payout_offset += MOCK_BONUS_OFFSETS[bonus_value()]
    end

    payout_index = MOCK_PAYOUT_LOOKUP[payout_offset]
    @payout_counters[payout_index] += 1
  end
end

class Experiment
  def initialize()
    @mockSubject = MockCrossword.new()
    @realSubject = Crossword.with_words.where( :id => 69 ).first();

    # @realSubject.revealed = 'moqjuepwakinvzhcby'
    # @realSubject.revealed = 'moqjuepwakin'
    # @realSubject.revealed = 'moqjuepwa'
    # @realSubject.revealed = 'moqjue'
    # @realSubject.revealed = 'moq'
    # @realSubject.revealed = ''

    @realSubject.revealed = 'moqjuep'

    @realSubject.last_calc_revealed = 'xox';
  end

  def run_test()
    time = Time.now
    Benchmark.bmbm(7) do |x|
      x.report('First Mock: ')  { @mockSubject.recalculate(); }
      x.report('Second Mock: ')  { @mockSubject.recalculate(); }
      x.report('Third Mock: ')  { @mockSubject.recalculate(); }
      x.report('Fourth Mock: ')  { @mockSubject.recalculate(); }
      x.report('Fifth Mock: ')  { @mockSubject.recalculate(); }
    
    later = Time.now
    puts "Time elapsed #{(later-time)*1000} milliseconds"
    time = later
    
      x.report('First Real: ')  { @realSubject.recalculate(); }
      @realSubject.last_calc_revealed = 'xox';
      x.report('Second Real: ')  { @realSubject.recalculate(); }
      @realSubject.last_calc_revealed = 'xox';
      x.report('Third Real: ')  { @realSubject.recalculate(); }
      @realSubject.last_calc_revealed = 'xox';
      x.report('Fourth Real: ')  { @realSubject.recalculate(); }
      @realSubject.last_calc_revealed = 'xox';
      x.report('Fifth Real: ')  { @realSubject.recalculate(); }
    
    later = Time.now
    puts "Time elapsed #{(later-time)*1000} milliseconds"
    time = later

      x.report('First Theory: ')  { @mockSubject.recount(); }
      x.report('Second Theory: ')  { @mockSubject.recount(); }
      x.report('Third Theory: ')  { @mockSubject.recount(); }
      x.report('Fourth Theory: ')  { @mockSubject.recount(); }
      x.report('Fifth Theory: ')  { @mockSubject.recount(); }
    end

    later = Time.now
    puts "Time elapsed #{(later-time)*1000} milliseconds"
    time = later
  end
  
  def report
    # @mockSubject.report() 
    time = Time.now
    Benchmark.bm(7) do |x|
      x.report('First Experiment: ')  { @mockSubject.reconsider(); }
      x.report('Second Experiment: ')  { @mockSubject.reconsider(); }
      x.report('Third Experiment: ')  { @mockSubject.reconsider(); }
      x.report('Fourth Experiment: ')  { @mockSubject.reconsider(); }
    end
    
    later = Time.now
    puts "Time elapsed #{(later-time)*1000} milliseconds"
  end
end


demo = Experiment.new()
demo.report()
while (true) do
  demo.run_test()
end

