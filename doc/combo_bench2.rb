require 'benchmark'
require 'set'
load 'bitset_twiddler.rb'

module ApplicationHelper
  class ComboBench
    ALPHAFIELD = (1 << 26) - 1
  
    def initialize() 
      @letter_on_array = (0..25).map {|x| 1 << x}
      @letter_off_array = @letter_on_array.map {|x| ALPHAFIELD & ~x}
      words = ['resist', 'diary', 'mug', 'solo', 'agency', 'ant', 'menu', 'odd',
               'aunt', 'dim', 'drift', 'sprint', 'battery', 'jeopardy', 'swing',
               'atom', 'huge', 'dot', 'rice', 'sympathy', 'volunteer', 'auto'];
  
      @words_a =
        words.map {|w| w.codepoints.reduce(0) {|mask, cp| mask | (1 << (cp-97))}}
   
      @letter_usage_array = @letter_on_array.map {|l| [l, (0..23).select {|w| (w&l) == l}]}
      
      wrapped_words_a = @words_a.map do |w| [w]; end
  
      @letter_wrap_list_array =
        @letter_on_array.map do |l|
          [ l, wrapped_words_a.select do |ww| ww[0] & l == l; end ]
        end
  
      @letter_wrap_set_array =
        @letter_wrap_list_array.map do |lww| [lww[0], lww[1].to_set]; end
    end
  
    def run_by_brute_force(size)
      sum = 0
      count = 0
      @letter_on_array.combination(size) do |combo|
        mask = ALPHAFIELD & ~combo.reduce {|fields, term| fields|term}
        sum += @words_a.map {|w| ((w&mask) == 0) ? 1 : 0}.reduce {|s,v| s+v}
        count += 1
      end
    
      puts "Sum: #{sum}, Count: #{count}, Avg: #{sum/count}"
      return sum / count
    end
  
    def run_by_brute_force_v2(size)
      sum = 0
      count = 0
      @letter_off_array.combination(size) do |combo|
        mask = combo.reduce(ALPHAFIELD) {|mask, term| mask&term }
        sum += @words_a.map {|w| ((w&mask) == 0) ? 1 : 0}.reduce {|s,v| s+v}
        count += 1
      end
    
      puts "Sum: #{sum}, Count: #{count}, Avg: #{sum/count}"
      return sum / count
    end
    
    def run_by_bitset_twiddle(size)
      sum = 0
      count = 0
    
      # Initialize a bitset twiddler to run through all the permutations of size "size" over a
      # domain of 26 letters.
      BitsetTwiddler.new(26-size, 26).each do |m|
        # puts (0..25).map {|d| ((m & (1<<d)) == 0) ? 0 : 1 }.inspect
        sum +=
          @words_a.map do |w| ((w&m) == 0) ? 1 : 0 end.reduce do |s,v| s+v; end 
        count += 1
      end 
    
      puts "Sum: #{sum}, Count: #{count}, Avg: #{sum/count}"
      return sum / count
    end
  
    def run_letter_deltas_by_array(size)
      sum = 0
      count = 0
      last_mask = ALPHAFIELD
      last_combo = Array.new
  
      @letter_on_array.combination(size) do |combo|
        # A 1 in a word bit-field means letter required.  A 0 in the bit string
        # derived from the player's letters means that letter is present.  By
        # ANDing a word bit-field with a player's available letter bit-field, 
        # covered letters are found when the result equals 0.  Any other result
        # has 1's where the player lacked 0's, which correspond to the letters 
        # missing to complete the word.
  
        # First, build a mask for letters from the previous combination that 
        # were dopped in reaching the current one.  Prepare a bit mask to 
        # use for clearing those letters from this iteration's bitmask. 
        next_mask = 
          combo.reduce(0) do |mask, lw|
            if last_combo.delete?(lw) == lw then mask; else mask|lw; end
          end
  
        # Toggle the positions for removed letters from 0->1 by inverting and
        # AND ing hte previous mask.  To handle the letters that have been added,
        # simply OR their single 1-bit 
        last_mask = last_combo.reduce(last_mask & (~next_mask)) {|m, lw| m|lw; }
        last_combo = combo
  
        # Derive a score by masking each word and counting the 0's.
        sum += @words_a.reduce(0) {|s, w| ((w & last_mask) == 0) ? s+1 : s}
        count += 1
      end
  
      puts "Sum: #{sum}, Count: #{count}, Avg: #{sum/count}"
      return sum / count
    end
  
    def run_letter_deltas_by_set(size)
      sum = 0
      count = 0
      last_mask = ALPHAFIELD
      last_combo = Set.new
  
      # TODO: Make sure the arguments resolve left to right, otherwise iteration through
      #       last_combo might happen before its undesireables are removed.  This can
      #       be worked around if its an issue by combining last_mask with the negated
      #       reduce value inside the parameter list for the second reduce, at a small
      #       hit to code-reading complexity.
      @letter_on_array.combination(size) do |combo |
        last_mask = 
          ~combo.reduce(0) {|m, lw| (last_combo.delete?(lw) == lw) ? m : m|lw} &
          last_combo.reduce(last_mask) {|m, lw| m|lw}
  
        last_combo = combo.to_set
  
        sum += @words_a.reduce(0) do |s, w| ((w & last_mask) == 0) ? s+1 : s end 
        count += 1
      end
  
      puts "Sum: #{sum}, Count: #{count}, Avg: #{sum/count}"
      return sum / count
    end
   
    def run_word_deltas_by_arrays(size)
      sum = 0
      count = 0
      last_score = 0
      last_usage = 0
      last_mask = ALPHAFIELD
  
      @letter_usage_array.combination(size) do |combo|
        usage = ~combo.reduce {|mu,lw| [mu[0]|lw[0], mu[1]|lw[1]] }
        mask = ALPHAFIELD & usage[0]
        usage = usage[1]
  
        # Evaluate the incremental effect of additions and removals on the
        # previous score, then propogate this iteration calculations on to the
        # next iteration
        last_score =
          last_combo.reduce(
            combo.reduce(last_score) do |score, lw|
              (last_combo.include?(lw) or (next_mask & word != 0)) ? score : score+1
            end
          ) do |score, lw| 
            (combo.include?(lw) or (last_mask & word != 0)) ? score : score-1
          end
  
        last_mask = next_mask
        last_combo = combo
  
        sum += last_score
        count += 1
      end
  
      puts "Sum: #{sum}, Count: #{count}, Avg: #{sum/count}"
      return sum / count
    end
      
    def run_word_deltas_by_set(size)
      sum = 0
      count = 0
      last_score = 0
      last_mask = ALPHAFIELD
      next_mask = 0
      last_combo = Array.new
      last_combo_set = Set.new
  
      @letter_usage_array.combination(size) do |combo|
        combo_set = combo.to_set
  
        # Words to re-score at end-of-loop.  Adds and deletes are not tracked
        # separataely--it's cheaper to resolve the difference by checking the 
        # bitmask twice, although....
        #
        # TODO: Consider counting to guess which bitmask is more efficiently
        #       checked first because missing it allows the other to be presumed
        #       a given.
        check_words = Set.new
  
        # TODO: Reverse the comment.  Adds then drops
        #
        # Accumulate the 1 bits for all letters that dropped out since the last
        # iteration so the accumulated bitstring can be used to flip all the 
        # same bits in the next word-matching bitmask.
        #
        # At the same time, identify any words affected by removal that are
        # no longer complete and decrement the previous score by the same
        # amount.
        next_mask = 
          combo.reduce(0) do |mask, lw|
            if (! last_combo_set.include?(lw))
              check_words.merge(lw[1])
              mask | lw[0]
            else
              mask
            end
          end
  
        # The word matching mask uses 0's to mark a letter that is in the
        # selected letter pool.  Flip all 1's for the removed letters back to
        # 0's.  Then iterate over the added letters and flip their 0's to 1's.
        #
        # Meanwhile, build a list of words to check for score increases after
        # the complete bitmask for this iteration has been built.
        next_mask =
          last_combo.reduce(last_mask & (~next_mask)) do |mask, lw|
            if (! combo_set.include?(lw)) 
              check_words.merge(lw[1])
              mask | lw[0]
            else
              mask
            end
          end
  
        # Evaluate the incremental effect of additions and removals on the
        # previous score, then propogate this iteration calculations on to the
        # next iteration
        last_score =
          check_words.reduce(last_score) do |score, word| 
            ((last_mask & word) == 0) ?
              ((next_mask & word) == 0) ? score : score-1 :
              ((next_mask & word) == 0) ? score+1 : score
          end
  
        last_mask = next_mask
        last_combo_set = combo_set
        last_combo = combo
        sum += last_score
        count += 1
      end
  
      puts "Sum: #{sum}, Count: #{count}, Avg: #{sum/count}"
      return sum / count
    end
      
    def run_test(repeats, size_array) 
      repeats.times do
        Benchmark.bmbm(7) do |x|
          for size in size_array do
            x.report("Pure Brute Force #{size}") do run_by_brute_force(size) end
            x.report("Pure Brute Force, V2 #{size}") do run_by_brute_force_v2(size) end
            x.report("Bitset Twiddler #{size}") do run_by_bitset_twiddle(size) end
            # x.report("Letter Deltas By Set #{size}") do run_letter_deltas_by_set(size) end
            # x.report("Letter Deltas By Array #{size}") do run_letter_deltas_by_array(size) end
            # x.report("Word Deltas By Set #{size}") do run_word_deltas_by_set(size) end
            # x.report("Word Deltas By Array #{size}") do run_word_deltas_by_arrays(size) end
          end
        end
      end
    end
  end
  
  demo = ComboBench.new()
  demo.run_test(3, [26   ])
  demo.run_test(3, [22])
  demo.run_test(3, [18])
end
