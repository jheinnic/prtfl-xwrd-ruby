class WordTrace
  def initialize(bits, tli)
    @binary_value = bits
    @triples_prize = (tli > -1)
  end

  def binary_value()
    return @binary_value
  end

  def triples_prize()
    return @triples_prize
  end
end

class Crossword < ActiveRecord::Base
  attr_accessible :bonus_value, :bonus_word, :revealed, :word_items_attributes

  # Calculated state that is not elgibile for user assignment, but is also
  # persisted to avoid re-calculation between uses.
  attr_reader :last_calc_revealed, :actual_payout, :pays00, :pays01, :pays02, :pays03, :pays04, :pays05, :pays06, :pays07, :pays08, :pays09, :pays10, :pays11, :pays12, :pays13, :pays14, :pays15, :pays16, :pays17
  
  before_validation :recalculate
  
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

  # The bitfield calculated for a string is a single integer value such that
  # the bit position for each letter has a value of 1 if that letter was used 
  # at least once in the string, othewise a value of 0.
  def self.word_to_bitfield(word = '') 
    val = 0
    word.codepoints { |cp| val = val | (1 << (cp-97)) }
    return val
  end

  # There is also a use case for representing a string as a set of integer
  # values, with one value for each unique letter used at least once.  The
  # sense of 1 and 0 are inverted, such that each value in the array has one
  # 0 and twenty-five 1's.  The single 0 is at the position of one of the 
  # letters present in the input string.  This rule covers bit positions 0
  # through 25 of each member value in the returned set.  Bits 26 to 35 are
  # always 0, no matter what the input.
  def self.word_to_bitset(word = '') 
    val = Array[]
    word.codepoints { |cp| val.push(ALPHAFIELD & ~(1 << (cp-97))) }
    return val
  end

  ALPHABET   = 'abcdefghijklmnopqrstuvwxyz'
  ALPHAFIELD = word_to_bitfield(ALPHABET)
  ALPHASET   = word_to_bitset(ALPHABET)

  PLAYED_LETTER_COUNT = 18
  UNUSED_LETTER_COUNT = 8

  def recalculate
    return unless new_calculation_possible?

    # To test for word coverage, we want a string where all of a player's 
    # letters are 0's, and all unavailable letter are 1's.  The 0's from
    # the currently-revealed letters will always be present with each
    # hypothetical combination of unknowns, so compute them outside of the
    # testing loop.
    @known_bitfield = ALPHAFIELD & ~(Crossword.word_to_bitfield(revealed))
    @unused_bitset  = ALPHASET - Crossword.word_to_bitset(revealed)

    # Extract information needed from the WordItem objects so we need not
    # incur the over head of ActiveRecord access during the payout frequency
    # computation.  This accelerates the time cost to 1/25 of the time cost.
    @basic_words =
     word_items.collect { |wi|
       WordTrace.new(
         Crossword.word_to_bitfield(wi.text_value), wi.triple_letter_index
       )
     }
    @triple_words = @basic_words.select { |wt| wt.triples_prize() }
    @basic_words.reject! { |wt| wt.triples_prize() }

    # Transform the bonus word for easy comparison too.
    @bonus_bitfield = Crossword.word_to_bitfield(self[:bonus_word])

    # Zero out an array of counters so we can defer mapping indices to variable
    # names until after all the counters have accumulated their frequencies.
    @payout_counters = Array.new(18, 0)
    @unused_bitset.combination(@unused_bitset.size - UNUSED_LETTER_COUNT) {
      |next_combination| calculate_payout(next_combination) }
    
    # Transfer the counter array to the "paysNN" field set.
    set_payout_counters
  end

  # Only return true when we have both enough information to do a calculation
  # and a change to the "revealed" character set, without which we would merely
  # calculate the same values currently stored.
  def new_calculation_possible?
    (self.bonus_value > -1) and
    (self.bonus_value < 4) and
    (self.bonus_word.length == 5) and
    (self.word_items.size == 22) and
    (self.revealed != self.last_calc_revealed) and
    (self.word_items.select { |i| i.triple_letter_index >= 0 }.size == 4)
  end

  private
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
  def calculate_payout(hypothesis)
    # Zero out additional bits in @known_bitfield corresponding to the input
    # hypothetical combination of unused letters for each remaining unknown
    # "your letters" slot.  The resulting string will have 18 0's and 8 1's
    # such that a logical AND between it and any word's bitfield will yield
    # 0 iff it can be completed with the 18 chosen letters (union of fixed 
    # and hypothetical subsets always yields a union of size 18).
    coverage = @known_bitfield
    hypothesis.each { |next_guess| coverage &= next_guess }

    # Score the combination's crossword hits and look for a tripling modifier
    # by performing bitwise ANDs of the word string (where letters present are
    # 1's) and the hypothesis coverage (where letters present are 0's).  If
    # the result is 0, then the word was covered and counts towards a prize.
    payout_offset = triple_offset = 0
    @basic_words.each { |wt|
      payout_offset += 1 if ((coverage & wt.binary_value()) == 0)
    }
    @triple_words.each { |wt|
      if ((coverage & wt.binary_value()) == 0) then
        payout_offset += 1
        triple_offset = TRIPLE_MATCH_PAYOUT_OFFSET
      end
    }

    # The triple_offset will be 0 or 115 and so can be added unconditionally.
    payout_offset += triple_offset

    # Score the bonus word.  A bit-wise AND resulting in zero is a bonus win.
    # Any non-zero value indicates at least one of the bonus word letters was
    # at the same bit slot as one of the eight 1's representing the eight
    # unused letters for the combination being assessed.
    if ((coverage & @bonus_bitfield) == 0) then
      payout_offset += BONUS_OFFSETS[bonus_value]
    end

    # We've calculated the 1-dimensional projection of the 3-dimensional 
    # coordinates for the payout the hypothetical combination will yield
    # if it turns out to be the way the "Your Letters" slots get filled.
    # De-reference the payout value, increment its frequency counter by
    # one, then return.
    @last_payout = PAYOUT_LOOKUP[payout_offset]
    @payout_counters[@last_payout] += 1
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

    # We know the bonus value, all 23 target words, and the location of
    # every tripling modifier.  If we've also just revealed the last of the
    # 18 "player letters", then we've just calculated the actual payout for
    # this ticket, not just one of several hypothetical possibilties.
    self[:actual_payout] = @last_payout if @unused_bitset.size() == UNUSED_LETTER_COUNT

    # Record what the stats stored were derived from, both for testing when
    # the results have become stale and for expressing what they reflect upon.
    self[:last_calc_revealed] = self[:revealed]
  end
end
