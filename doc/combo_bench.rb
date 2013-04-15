require 'benchmark'
require 'set'

class ComboTest 
  ALPHAFIELD = (1 << 26) - 1

  def run_by_brute_force(size)
    sum = 0
    count = 0
    @letter_array.combination(size) do |combo|
      bit_mask = ALPHAFIELD & ~(combo.reduce do |avg, item| avg | item; end)
      sum +=
        @word_array.map do |w|
          ((w & bit_mask) == 0) ? 1 : 0
        end.reduce do |score, value|
          score + value
        end 
      count += 1
    end

    puts "Sum: #{sum}, Count: #{count}, Avg: #{sum/count}"
    return sum / count
  end

  def run_letter_deltas_by_array(size)
    sum = 0
    count = 0
    last_bitmask = ALPHAFIELD
    last_combo = Array.new

    @letter_array.combination(size) do |combo|
      # A 1 in a word bit-field means letter required.  A 0 in the bit string
      # derived from the player's letters means that letter is present.  By
      # ANDing a word bit-field with a player's available letter bit-field, 
      # covered letters are found when the result equals 0.  Any other result
      # has 1's where the player lacked 0's, which correspond to the letters 
      # missing to complete the word.

      # First, build a mask for letters from the previous combination that 
      # were dopped in reaching the current one.  Prepare a bit mask to 
      # use for clearing those letters from this iteration's bitmask. 
      next_bitmask = 
        combo.reduce(0) do |mask, lw|
          if last_combo.include?(lw) then mask; else mask|lw; end
        end

      # Toggle the positions for removed letters from 0->1 by inverting and
      # AND ing hte previous mask.  To handle the letters that have been added,
      # simply OR their single 1-bit 
      last_bitmask =
        last_combo.reduce(last_bitmask & (~next_bitmask)) do |mask, lw|
          if combo.include?(lw) then mask; else mask|lw; end
        end
      last_combo = combo

      # Derive a score by iterating through all the words and counting up from
      # zero.
      sum +=
        @word_array.reduce(0) do |score, w|
          ((w & last_bitmask) == 0) ? score + 1 : score
        end 
      count += 1
    end

    puts "Sum: #{sum}, Count: #{count}, Avg: #{sum/count}"
    return sum / count
  end

  def run_letter_deltas_by_set(size)
    sum = 0
    count = 0
    last_bitmask = ALPHAFIELD
    last_combo = Array.new
    last_combo_set = Set.new

    @letter_array.combination(size) do |combo|
      combo_set = combo.to_set()

      # A 1 in a word bit-field means letter required.  A 0 in the bit string
      # derived from the player's letters means that letter is present.  By
      # ANDing a word bit-field with a player's available letter bit-field, 
      # covered letters are found when the result equals 0.  Any other result
      # has 1's where the player lacked 0's, which correspond to the letters 
      # missing to complete the word.

      # First, build a mask for letters from the previous combination that 
      # were dopped in reaching the current one.  Prepare a bit mask to 
      # use for clearing those letters from this iteration's bitmask. 
      next_bitmask = 
        combo.reduce(0) do |mask, lw|
          if last_combo_set.include?(lw) then mask; else mask|lw; end
        end

      # Toggle the positions for removed letters from 0->1 by inverting and
      # AND ing hte previous mask.  To handle the letters that have been added,
      # simply OR their single 1-bit 
      last_bitmask =
        last_combo.reduce(last_bitmask & (~next_bitmask)) do |mask, lw|
          if combo_set.include?(lw) then mask; else mask|lw; end
        end

      # Setup for the next iteration.  Do this before scoring the current 
      # iteration so we can access the bitmask with additions and removals
      # accounted for without repeatedly indexing into after_drops[0].
      last_combo = combo
      last_combo_set = combo_set

      # sum +=
      last_score =
        @word_array.reduce(0) do |score, w|
          ((w & last_bitmask) == 0) ? score + 1 : score
        end 
      sum += last_score
      count += 1
    end

    puts "Sum: #{sum}, Count: #{count}, Avg: #{sum/count}"
    return sum / count
  end
 
  def run_word_deltas_by_arrays(size)
    sum = 0
    count = 0
    last_score = 0
    last_bitmask = ALPHAFIELD
    last_combo = Array.new

    @letter_set_array.combination(size) do |combo|
      # TODO: Reverse the comment.  Adds then drops
      #

      # Words to re-score at end-of-loop.  Adds and deletes are not tracked
      # separataely--it's cheaper to resolve the difference by checking the 
      # bitmask twice, although....
      #
      # TODO: Consider counting to guess which bitmask is more efficiently
      #       checked first because missing it allows the other to be presumed
      #       a given.
      check_words = Set.new

      # Accumulate the 1 bits for all letters that were added since the last
      # iteration so the accumulated bitstring can be used to flip all the 
      # same bits in the next word-matching bitmask.  Accumulate a list of the
      # words to check for score increases after the new bitmask is known.
      next_bitmask = 
        combo.reduce(0) do |mask, lw|
          if (! last_combo.include?(lw))
            check_words.merge(lw[1]);
            mask | lw[0]
          else
            mask
          end
        end

      # temp_words = Set.new
      # Toggle the bits for characters added from 1 to 0, then begin iterating
      # through characters that have been removed, setting toggling their 0's
      # in the bitmask to 1's.  Accumulate a set of words that will be 
      # scanned for score decrements due to loss of a required letter between
      # this iteration and the last.
      next_bitmask =
        last_combo.reduce(last_bitmask & (~next_bitmask)) do |mask, lw|
          if (! combo.include?(lw))
            check_words.merge(lw[1])
            mask | lw[0]
          else
            mask
          end
        end

      # puts "Add: #{check_words}, Drop: #{temp_words}, Only Add: #{check_words - temp_words}, Only Drop: #{temp_words - check_words}, Both: #{check_words & temp_words}"
      # puts "Add: #{check_words.size}, Drop: #{temp_words.size}, Only Add: #{(check_words - temp_words).size}, Only Drop: #{(temp_words - check_words).size}, Both: #{(check_words & temp_words).size}"
      # puts "Add: #{check_words.select do |w| w&last_bitmask == 0; end.size}, Drop: #{temp_words.select do |w| w&last_bitmask == 0; end.size}, Only Add: #{(check_words - temp_words).select do |w| w&last_bitmask == 0; end.size}, Only Drop: #{(temp_words - check_words).select do |w| w&last_bitmask == 0; end.size}, Both: #{(check_words & temp_words).select do |w| w&last_bitmask == 0; end.size}"
      # puts "Add: #{check_words.select do |w| w&next_bitmask == 0; end.size}, Drop: #{temp_words.select do |w| w&next_bitmask == 0; end.size}, Only Add: #{(check_words - temp_words).select do |w| w&next_bitmask == 0; end.size}, Only Drop: #{(temp_words - check_words).select do |w| w&next_bitmask == 0; end.size}, Both: #{(check_words & temp_words).select do |w| w&next_bitmask == 0; end.size}"
      # check_words.merge(temp_words)

      # Evaluate the incremental effect of additions and removals on the
      # previous score, then propogate this iteration calculations on to the
      # next iteration
      last_score =
        check_words.reduce(last_score) do |score, word| 
          ((last_bitmask & word) == 0) ?
            ((next_bitmask & word) == 0) ? score : score-1 :
            ((next_bitmask & word) == 0) ? score+1 : score
        end

      last_bitmask = next_bitmask
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
    last_bitmask = ALPHAFIELD
    next_bitmask = 0
    last_combo = Array.new
    last_combo_set = Set.new

    @letter_set_array.combination(size) do |combo|
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
      next_bitmask = 
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
      next_bitmask =
        last_combo.reduce(last_bitmask & (~next_bitmask)) do |mask, lw|
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
          ((last_bitmask & word) == 0) ?
            ((next_bitmask & word) == 0) ? score : score-1 :
            ((next_bitmask & word) == 0) ? score+1 : score
        end

      last_bitmask = next_bitmask
      last_combo_set = combo_set
      last_combo = combo
      sum += last_score
      count += 1
    end

    puts "Sum: #{sum}, Count: #{count}, Avg: #{sum/count}"
    return sum / count
  end
    
  def run_test(repeats, size_array) 
    @letter_array = [1 << 0, 1 << 1, 1 << 2, 1 << 3, 1 << 4, 1 << 5, 1 << 6, 1 << 7, 1 << 8, 1 << 9, 1 << 10, 1 << 11, 1 << 12, 1 << 13, 1 << 14, 1 << 15, 1 << 16, 1 << 17, 1 << 18, 1 << 19, 1 << 20, 1 << 21, 1 << 22, 1 << 23, 1 << 24, 1 << 25 ]
    words = ['resist', 'diary', 'mug', 'solo', 'agency', 'ant', 'menu', 'odd',
             'aunt', 'dim', 'drift', 'sprint', 'battery', 'jeopardy', 'swing',
             'atom', 'huge', 'dot', 'rice', 'sympathy', 'volunteer', 'auto'];

    @word_array =
      words.map do |w|
        w.codepoints.collect do
          |cp| 1 << (cp-97) 
        end.reduce do |mask, term|
          mask | term
        end
      end

    @word_set = @word_array.to_set
 
    @letter_set_array =
      @letter_array.map do |l|
        [ l, @word_set.select do |w| w & l == l; end ]
      end
    
    wrapped_word_array = @word_array.map do |w| [w]; end

    @letter_wrap_list_array =
      @letter_array.map do |l|
        [ l, wrapped_word_array.select do |ww| ww[0] & l == l; end ]
      end

    @letter_wrap_set_array =
      @letter_wrap_list_array.map do |lww| [lww[0], lww[1].to_set]; end

    repeats.times do
      Benchmark.bmbm(7) do |x|
        for size in size_array do
          x.report("Pure Brute Force #{size}") do run_by_brute_force(size) end
          x.report("Letter Deltas By Set #{size}") do run_letter_deltas_by_set(size) end
          x.report("Letter Deltas By Array #{size}") do run_letter_deltas_by_array(size) end
          x.report("Word Deltas By Set #{size}") do run_word_deltas_by_set(size) end
          x.report("Word Deltas By Array #{size}") do run_word_deltas_by_arrays(size) end
        end
      end
    end
  end
end

demo = ComboTest.new()
demo.run_test(3, [26])
demo.run_test(3, [22])
demo.run_test(3, [18])
# demo.run_test(3, [18])

