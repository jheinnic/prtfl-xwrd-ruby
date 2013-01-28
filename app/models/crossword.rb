class Crossword < ActiveRecord::Base
  attr_accessible :bonus_value, :bonus_word, :revealed, :word_items_attributes

  # Calculated state that is not elgibile for user assignment, but is also
  # persisted to avoid re-calculation between uses.
  attr_reader :last_calc_revealed, :actual_payout, :pays00, :pays01, :pays02, :pays03, :pays04, :pays05, :pays06, :pays07, :pays08, :pays09, :pays10, :pays11, :pays12, :pays13, :pays14, :pays15, :pays16, :pays17
  
  before_validation :attempt_calculation_if_stale
  
  has_many :word_items
  accepts_nested_attributes_for :word_items
    
  scope :with_words, includes(:word_items)
  scope :to_reveal_by_text, with_words.merge(WordItem.ro_textual)
  scope :to_reveal_by_gui, with_words.merge(WordItem.ro_graphical)
  scope :for_text_display, to_reveal_by_text.readonly
  scope :for_gui_display, to_reveal_by_gui.readonly
  scope :as_summary, select(
    [:id, :bonus_word, :actual_payout, :created_at, :updated_at]
  )

  # For combinations that hit the bonus word, the bonus value affects whether
  # the combination is possible and what value it pays out at if so.  The bonus
  # value is an initial unknown, so we track the distribution of winners for
  # each of the five possibilities.
  BONUS_OFFSETS = [22, 44, 66, 88]
  TRIPLE_MATCH_PAYOUT_OFFSET = 115;
  PAYOUT_LOOKUP = [
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
    val = Set[]
    word.codepoints { |cp| val = val << (1 << (cp-97)) }
    return val
  end

  ALPHABET   = 'abcdefghijklmnopqrstuvwxyz'
  ALPHAFIELD = word_to_bitfield(ALPHABET)
  ALPHASET   = word_to_bitset(ALPHABET)

  LETTERS_PRESENT_PER_TICKET = 18
  LETTERS_ABSENT_PER_TICKET = 8
  FINAL_KNOWN_LETTER_INDEX = 17
  WORDS_PER_TICKET = 22
  NUM_BONUS_TIERS = 4
  EMPTY_SET = Set[]

  def recalculate
    return unless win_criteria_defined?

    parse_letter_sets if revealed != self[:last_calc_revealed]

    @num_combos = 0        
    @payout_counters = Array.new(18, 0)
    @unused_bitset.combination(@num_unknowns) { |next_combination|
      @num_combos += 1
      calculate_payout_index(next_combination)

      if @num_combos % 50000 == 0 
        logger.debug( "Evaluated combination #{@num_combos}: #{next_combination.inspect} from #{@unused_bitset.inspect} hypothetical combined with #{@known_bitfield.inspect} known." )
      end
    }

    logger.debug( "#{@num_unknowns} letters available and #{18 - @num_unknowns} letters already revealed yielded #{@num_combos} potential combinations")
    
    set_payout_counters
  end

  def win_criteria_defined?
    (self.bonus_value > -1) and
    (self.bonus_value < 4) and
    (self.bonus_word.length == 5) and
    (self.word_items.size == 22) and
    (self.word_items.select { |i| i.triple_letter_index >= 0 }.size == 4)
  end

  # def allocate_word_slots
  #  (1..WORDS_PER_TICKET).each {|i| 
  #    self.word_items.new(:x_coordinate  => 0, :y_coordinate => 0) }
  # end

  private
  def attempt_calculation_if_stale
    recalculate if revealed != self[:last_calc_revealed];
  end
  
  def parse_letter_sets
    known_letters   = revealed.nil? ? EMPTY_SET : Crossword.word_to_bitset(revealed)
    puts revealed
    puts known_letters.inspect
    @known_bitfield = ALPHAFIELD & (~ Crossword.word_to_bitfield(revealed))

    @num_unknowns   = LETTERS_PRESENT_PER_TICKET - known_letters.size
    @unused_bitset  = (ALPHASET - known_letters).to_a

    @word_bitfields =
      word_items.collect { |wi|
        Crossword.word_to_bitfield(wi.text_value) }
    @bonus_bitfield = Crossword.word_to_bitfield(self[:bonus_word])
  end

  def calculate_payout_index(hypothesis)
    # Zero out additional bits in @known_bitfield corresponding to the input
    # hypothetical combination of unused letters for each remaining unknown
    # "your letters" slot.  The resulting string will have 18 0's and 8 1's
    # such that a logical AND between it and any word's bitfield will yield
    # 0 iff it can be completed with the 18 chosen letters.
    coverage = 0
    hypothesis.each { |next_guess| coverage = (coverage | next_guess) }
    coverage = @known_bitfield & (~ coverage)

    # Score the bonus word.  A bit-wise AND resulting in zero is a bonus win.
    # Any non-zero value indicates at least one of the bonus word letters was
    # at the same bit slot as one of the eight 1's representing the eight
    # unused letters for the combination being assessed.
    bonus_winner = ((@bonus_bitfield & coverage) == 0)

    # Score the combination's crossword hits in O(|Words|) time, much better
    # than the O(|Words|*|UnknownLetters|) cost of iterating and counting.
    payout_offset = triple_offset = 0
    for ii in (0..21) do
      if ((@word_bitfields[ii] & coverage) == 0) then
        payout_offset += 1;
        if (word_items[ii].triple_letter_index > -1) then
          triple_offset = TRIPLE_MATCH_PAYOUT_OFFSET;
        end
      end
    end
    payout_offset += triple_offset
    
    # Lookup Index calculation is mapping into a three dimensional array with
    # dimension bounds of [1][5][23].
    # -- The third dimension is bounded by the number of words.  Between 0
    #    and 22 words requires 23 slots.
    # -- The second dimension replicates the 22 slots for a word count 5
    #    times for a region of 115 slots.  The 5 zones about for the effect
    #    of the 4 bonus word payout levels and the 5th possibility of missing
    #    the bonus word.
    # -- The first dimension has only two possible values--either a word with
    #    a prize tripling modifier was hit, or no such modifier was hit.
    #    Doubling the 115 slots required to allocate one for each combination
    #    of a word count (one of 23) and bonus result (one of 5) yields a total
    #    payout table size of 230 slots.
    #
    # As an added wrinkle, if the bonus value is not yet known, we have to
    # lambda methods accept an increment argument for this case when the
    # bonus has not been met.  When an unknown bonus is met, four different
    # payout values will get tabulated.  In order to avoid skewing the 
    # reported result, four idenitical counters must get incremented when
    # the bonus is missed when calculating prize odds with no knowledge of the
    # bonus' actual value.
    if (bonus_value >= 0) then
      if (bonus_winner) then
        payout_index = 
          PAYOUT_LOOKUP[payout_offset + BONUS_OFFSETS[bonus_value]]
      else
        payout_index = PAYOUT_LOOKUP[payout_offset]
      end

      @payout_counters[payout_index] += 1

      # We know the bonus value, all 23 target words, and the location of
      # every tripling modifier.  If we've also just revealed the last of the
      # 18 "player letters", then we've just calculated the actual payout for
      # this ticket, not just one of several hypothetical possibilties.
      self[:actual_payout] = payout_index if @num_unknowns == 0
    else
      # NOTE: Business logic currently makes this code for calculating odds
      #       absent knowledge of the true bonus value unreachable.
      if (bonus_winner) then 
        BONUS_OFFSETS.each { |bonus_tier|
          @payout_counters[PAYOUT_LOOKUP[payout_offset + bonus_tier]] += 1 }
      else
        @payout_counters[PAYOUT_LOOKUP[payout_offset]] += 4
      end
    end
  end
  
  def clear_payout_counters
    self[:pays00] = self[:pays01] = self[:pays02] = 0
    self[:pays03] = self[:pays04] = self[:pays05] = 0
    self[:pays06] = self[:pays07] = self[:pays08] = 0
    self[:pays09] = self[:pays10] = self[:pays11] = 0
    self[:pays12] = self[:pays13] = self[:pays14] = 0
    self[:pays15] = self[:pays16] = self[:pays17] = 0
  end
  
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
    self[:last_calc_revealed] = self[:revealed]
  end
end
