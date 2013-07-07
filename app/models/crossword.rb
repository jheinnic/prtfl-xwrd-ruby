class Counter
  def initialize( word, needed, isTriple, isBonus ) 
    @word = word
    @needed = needed
    @isTriple = isTriple
    @isBonus = isBonus
  end

  def cover()
    @needed = @needed - 1
    return :no_change if @needed > 0

    return :score_triple if @isTriple

    return :score_bonus if @isBonus

    return :score_word
  end

  def uncover()
    @needed = @needed + 1
    return :no_change if @needed > 1

    return :lose_triple if @isTriple

    return :lose_bonus if @isBonus

    return :lose_word
  end
end

class Crossword < ActiveRecord::Base
  attr_accessible :bonus_value, :bonus_word, :revealed, :word_items_attributes

  # Calculated state that is not elgibile for user assignment, but is also
  # persisted to avoid re-calculation between uses.
  attr_reader :last_calc_revealed, :actual_prize, :pays00, :pays01, :pays02, :pays03, :pays04, :pays05, :pays06, :pays07, :pays08, :pays09, :pays10, :pays11, :pays12, :pays13, :pays14, :pays15, :pays16, :pays17
  
  before_validation :recalculate
  
  has_many :word_items
  accepts_nested_attributes_for :word_items
    
  scope :with_words, includes(:word_items)
  scope :to_reveal_by_text, with_words.merge(WordItem.ro_textual)
  scope :to_reveal_by_gui, with_words.merge(WordItem.ro_graphical)
  scope :for_text_display, to_reveal_by_text.readonly
  scope :for_gui_display, to_reveal_by_gui.readonly
  scope :as_summary, select(
    [:id, :bonus_word, :actual_prize, :created_at, :updated_at]
  )

  # For combinations that hit the bonus word, the bonus value affects whether
  # the combination is possible and what value it pays out at if so.  The bonus
  # value is an initial unknown, so we track the distribution of winners for
  # each of the five possibilities.
  PAYOUT_LOOKUP =
  [ # First dimmension: Tripled or not? (2 possibilities)
    [ # Second dimension, no bonus (0) or bonus word completed (1 through 4)
      # Third dimension: 0-22 words covered) (23 possibilities)

      # No Bonus, No Triple
      [ 0, 0, 1, 2, 3, 4, 7, 9, 11, 14, 16, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17 ], 
      # $4 Bonus, No Triple
      [ 2, 2, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17 ],
      # $5 Bonus, No Triple
      [ 3, 3, 17, 17, 4, 6, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17 ],
      # $10 Bonus, No Triple
      [ 4, 4, 17, 17, 6, 7, 8, 10, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17 ],
      # $30 Bonus, No Triple
      [ 8, 8, 17, 17, 17, 17, 9, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17 ]
    ], [
      # No Bonus, With Triple
      [ 17, 0, 17, 5, 6, 8, 10, 12, 13, 15, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17 ],
      # $4 Bonus, With Triple
      [ 17, 2, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17 ],
      # $5 Bonus, With Triple
      [ 17, 3, 17, 17, 7, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17 ],
      # $10 Bonus, With Triple
      [ 17, 4, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17 ],
      # $30 Bonus, No Triple
      [ 17, 8, 17, 17, 17, 10, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17 ]
    ]
  ]

  # The bitfield calculated for a string is a single integer value such that
  # the bit position for each letter has a value of 1 if that letter was used 
  # at least once in the string, othewise a value of 0.
  def self.word_to_bitfield(word, alphabet) 
    return word.chars.reduce(0) { |m,c| (alphabet[c] || 0) }
  end

  ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.chars.to_a
  UNUSED_LETTER_COUNT = 8

  # Only return true when we have both enough information to do a calculation
  # and a change to the "revealed" character set, without which we would merely
  # calculate the same values currently stored.
  def new_calculation_possible?
    (self.bonus_value > -1) and (self.bonus_value < 4) and
    (! self.bonus_word.nil?) and (self.bonus_word.length == 5) and
    # ( (self.last_calc_revealed.nil?) or
    #   (self.revealed.length < self.last_calc_revealed.length) ) and
    (self.revealed.length == 18) and (self.word_items.size == 22) and
    (self.word_items.where(:triple_letter_index => -1).count() == 18)
  end

  def recalculate
    return unless new_calculation_possible?

    # To test for word coverage, we want a string where all of a player's 
    # letters are 0's, and all unavailable letter are 1's.  Only letters that
    # are not among those already revealed are assigned a bit position.
    known  = revealed.upcase.chars.to_set
    @letters_unused = 26 - known.size

    unused = Hash[
      ALPHABET.select do |c|
        !known.include?(c)
      end.map {|c| [c, Array.new]}
    ]

    words_scored = 0
    triples_scored = 0
    word_items.each do |w|
      needed = w.text_value.chars.to_set - known
      if (needed.size > 0)
        counter = Counter.new(w.text_value, needed.size, w.triple_letter_index != -1, false)
        needed.each {|l| unused[l] << counter}
      else
        words_scored = words_scored + 1
        triples_scored = triples_scored + 1 if (w.triple_letter_index != -1) 
      end
    end
     
    # Transform the bonus word for easy comparison too.
    needed = bonus_word.chars.to_set - known
    if (needed.size > 0)
      bonus_index = 0
      @bonus_value = bonus_value
      counter = Counter.new(bonus_word, needed.size, false, true)
      needed.each {|l| unused[l] << counter}
    else
      bonus_index = bonus_value
    end

    # Zero out an array of counters so we can defer mapping indices to variable
    # names until after all the counters have accumulated their frequencies.
    # @payout_counters.fill(0)
    @payout_counters = Array.new(18, 0)

    # Score an initial permutation of the first letters listed.
    @unknown_letters = unused.values 
    @unknown_letters.slice(
      UNUSED_LETTER_COUNT, @letters_unused - UNUSED_LETTER_COUNT
    ).each do |l|
      l.each do |counter|
        result = counter.cover()
        if result != :no_change
          if result == :score_word 
            words_scored = words_scored + 1
          elsif result == :score_triple
            words_scored = words_scored + 1
            triples_scored = triples_scored + 1
          else
            bonus_index = @bonus_value
          end
        end
      end
    end

    @last_payout =
      PAYOUT_LOOKUP[triples_scored > 0 ? 1 : 0][bonus_index][words_scored]
    @payout_counters[@last_payout] += 1

    # Swap one letter in and one letter out each iteration until we have 
    # visitted each permutation.  Track the incremnetal changes to payout.
    ApplicationHelper::SwapTwiddler.new(
      @letters_unused - UNUSED_LETTER_COUNT, @letters_unused
    ).each do |next_combo| 
      @unknown_letters[next_combo[0]].each do |counter|
        result = counter.uncover()
        if result != :no_change
          if result == :lose_word
            words_scored = words_scored - 1
          elsif result == :lose_triple
            words_scored = words_scored - 1
            triples_scored = triples_scored - 1
          else 
            bonus_index = 0
          end
        end
      end

      @unknown_letters[next_combo[1]].each do |counter|
        result = counter.cover()
        if result != :no_change
          if result == :score_word
            words_scored = words_scored + 1
          elsif result == :score_triple
            words_scored = words_scored + 1
            triples_scored = triples_scored + 1
          else 
            bonus_index = @bonus_value
          end
        end
      end

      # puts "#{words_scored}, #{triples_scored}, #{bonus_index}"
      @last_payout =
        PAYOUT_LOOKUP[triples_scored > 0 ? 1 : 0][bonus_index][words_scored]
      @payout_counters[@last_payout] += 1
    end
    
    # Transfer the counter array to the "paysNN" field set.
    set_payout_counters
  end

  def allocate_word_slots
    22.times do
      self.word_items << WordItem.new
    end
  end

  private
  # Lookup Index calculation maps into a three dimensional array with bounds
  # of [1][5][23].
  # -- The third dimension is bounded by the number of words.  Between 0
  #    and 22 words requires 23 slots.
  # -- The second dimension replicates the 22 slots for a word count 5
  #    times for a region of 115 slots.  The 5 zones accout for the effect
  #    of the 4 bonus word payout levels and the 5th possibility of missing
  #    the bonus word.
  # -- The first dimension has only two possible values--either a word with
  #    a prize tripling modifier was hit, or no such modifier was hit.
  #    Doubling the 115 slots required to allocate one for each combination
  #    of a word count (one of 23) and bonus result (one of 5) yields a total
  #    payout table size of 230 slots.
  
  def set_payout_counters
    self[:pays00] = @payout_counters[0]
    self[:pays01] = @payout_counters[1]
    self[:pays02] = @payout_counters[2]
    self[:pays03] = @payout_counters[3]
    self[:pays04] = @payout_counters[4]
    self[:pays05] = @payout_counters[5]
    self[:pays06] = @payout_counters[6]
    self[:pays07] = @payout_counters[7]
    self[:pays08] = @payout_counters[8]
    self[:pays09] = @payout_counters[9]
    self[:pays10] = @payout_counters[10]
    self[:pays11] = @payout_counters[11]
    self[:pays12] = @payout_counters[12]
    self[:pays13] = @payout_counters[13]
    self[:pays14] = @payout_counters[14]
    self[:pays15] = @payout_counters[15]
    self[:pays16] = @payout_counters[16]
    self[:pays17] = @payout_counters[17]

    # We know the bonus value, all 23 target words, and the location of
    # every tripling modifier.  If we've also just revealed the last of the
    # 18 "player letters", then we've just calculated the actual payout for
    # this ticket, not just one of several hypothetical possibilties.
    # 
    # No need to check the unused letter count anymore since the server-side
    # calculation is only invoked after all user input has been given.
    self[:actual_prize] = @last_payout # if @letters_unused == UNUSED_LETTER_COUNT

    # Record what the stats stored were derived from, both for testing when
    # the results have become stale and for expressing what they reflect upon.
    #
    # Deprecating :last_calc_revealed...
    # self[:last_calc_revealed] = self[:revealed]
  end
end
