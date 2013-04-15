require 'benchmark'
require 'crossword'
require 'set'

class MockWordItem 
  def initialize(ones_not_marked)
    @letters_needed = ones_not_marked
    @score = 0
  end

  def letters_needed()
    return @letters_needed
  end

  def is_complete?() 
    return @score == 1
  end

  def are_needed?(ones_to_check)
    return @letters_needed & ones_to_check == ones_to_check
  end
  
  def mark(zeros_to_mark)
    @letters_needed = @letters_needed & zeros_to_mark

    @score = 1 if (@letters_needed == 0) 

    return @score
  end

  def unmark(ones_to_unmark)
    retVal = @score

    @letters_needed = @letters_needed | ones_to_unmark

    return retVal
  end
end

class MockLetterItem
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

  ALPHABET   = 'abcdefghijklmnopqrstuvwxyz'
  ALPHAFIELD = MockLetterItem.word_to_bitfield(ALPHABET)
  ALPHASET   = MockLetterItem.word_to_bitset(ALPHABET)

  def initialize(letter_bit, all_word_items)
    @as_one  = letter_bit
    @as_zero = ALPHAFIELD & ~letter_bit
    @words_touched = all_word_items.select {|w| w.are_needed?(letter_bit)}
  end

  def get_as_one(); return @as_one; end

  def get_as_zero(); return @as_zero; end

  def words_touched(); return @words_touched; end 

  def mark() 
    delta = 0
    @words_touched.each {|w| delta += w.mark(@as_zero)}
    return delta
  end

  def unmark()
    delta = 0
    @words_touched.each {|w| delta += w.unmark(@as_one)}
    return delta
  end
end


class Experiment
  def initialize()
    @words = ['resist', 'diary', 'mug', 'solo', 'agency', 'ant', 'menu', 'odd', 
              'aunt', 'dim', 'drift', 'sprint', 'battery', 'jeopardy', 'swing',
              'atom', 'huge', 'dot', 'rice', 'sympathy', 'volunteer', 'auto'];
    @wbits = @words.map {|w| MockLetterItem.word_to_bitfield(w) }
  end

  ALPHABET   = 'abcdefghijklmnopqrstuvwxyz'
  ALPHAFIELD = MockLetterItem.word_to_bitfield(ALPHABET)
  ALPHASET   = MockLetterItem.word_to_bitset(ALPHABET)

  def change_revealed(revealed)
    known_letters   = MockLetterItem.word_to_bitset(revealed)
    @known_bitfield = ALPHAFIELD & (~ MockLetterItem.word_to_bitfield(revealed))
    @num_unknowns   = 18 - known_letters.size
    @unused_bitset  = ALPHASET - known_letters

    reset_items()
  end

  def reset_items() 
    word_items = @wbits.map { |w| MockWordItem.new(w & @known_bitfield) }
    @unused_lobjs = @unused_bitset.map { |l| MockLetterItem.new(l, word_items) }

    puts @unused_lobjs.inspect
  end

  def useLetterForceWordForce()
    @unused_bitset.combination(@num_unknowns) { |next_combination|
      coverage = payout_offset = triple_offset = 0
      next_combination.each { |next_guess| coverage = (coverage | next_guess) }
      coverage = @known_bitfield & (~ coverage)
  
      @wbits.each {|word| payout_offset += 1 if ((word & coverage) == 0)}
      
      # if ((@bonus & coverage) == 0) then
      #   payout_offset += 100
      # end
    }
  end

  def useLetterDeltaWordForce()
    @last_combination = Array.new
    @last_coverage = @known_bitfield
    @unused_bitset.combination(@num_unknowns) { |next_combination|
      added = next_combination - @last_combination
      dropped = @last_combination - next_combination
      @last_combination = next_combination

      coverage = payout_offset = triple_offset = 0
      added.each { |next_guess| coverage = (coverage | next_guess) }
      coverage = @last_coverage & (~ coverage)
      dropped.each { |next_guess| coverage = (coverage | next_guess) }
  
      @wbits.each {|word| payout_offset += 1 if ((word & coverage) == 0)}
      
      # if ((@bonus & coverage) == 0) then
      #   payout_offset += 100
      # end
    }
  end

  def useLetterDeltaWordNaive()
    @last_combination = Array.new
    @last_payout_offset = 0
    @last_triple_offset = 0

    @unused_lobjs.combination(@num_unknowns) { |next_combination|
      added = next_combination - @last_combination
      dropped = @last_combination - next_combination
      @last_combination = next_combination

      payout_offset = @last_payout_offset
      triple_offset = @last_triple_offset

      dropped.each { |l| payout_offset -= l.unmark() }
      added.each { |l| payout_offset += l.mark() }
  
      # if ((@bonus & coverage) == 0) then
      #   payout_offset += 100
      # end
    }
  end

  def useLetterDeltaWordDelta()
    @last_combination = Array.new
    @last_payout_offset = 0
    @last_triple_offset = 0

    @unused_lobjs.combination(@num_unknowns) { |next_combination|
      added = next_combination - @last_combination
      dropped = @last_combination - next_combination
      @last_combination = next_combination

      payout_offset = @last_payout_offset
      triple_offset = @last_triple_offset

      drop_cover = 0
      add_cover = ALPHAFIELD

      dropped =
        dropped.collect { |l|
          drop_cover = drop_cover | l.get_as_one()
          l.words_touched()
        }.flatten().to_set()
      added =
        added.collect { |l|
          add_cover = add_cover & l.get_as_zero()
          l.words_touched()
        }.flatten().to_set()

      dropped.each { |w| payout_offset -= w.unmark(drop_cover) }
      added.each { |w| payout_offset += w.mark(add_cover) }

      # if ((@bonus & coverage) == 0) then
      #   payout_offset += 100
      # end
    }
  end
 
  def run_test()
    Benchmark.bmbm(7) do |x|
      x.report('Brute Force All: ')  { useLetterForceWordForce(); }

      x.report('Brute Force Words Only: ')  { useLetterDeltaWordForce(); }

      reset_items();
      x.report('Naive Incremental: ')  { useLetterDeltaWordNaive(); }

      reset_items();
      x.report('Pure Incremental: ')  { useLetterDeltaWordDelta(); }
    end
  end
end

# 'yuehwpivjzrsbfcnoa'

demo = Experiment.new()
# demo.initialize()

demo.change_revealed( 'yuehwpi' ) 

while (true) do
  demo.run_test()
end

