class Crossword < ActiveRecord::Base
  attr_accessible :bonus_value, :bonus_word, :revealed, :word_items_attributes

  # Calculated state that is not elgibile for user assignment, but is also
  # persisted to avoid re-calculation between uses.
  attr_reader :last_calc_revealed, :actual_payout, :pays00, :pays01, :pays02, :pays03, :pays04, :pays05, :pays06, :pays07, :pays08, :pays09, :pays10, :pays11, :pays12, :pays13, :pays14, :pays15, :pays16, :pays17
  
  before_validation :ensure_calculation_if_dirty
  #after_initialize :initialize_word_holders, :on => :create
  after_initialize :parse_letter_sets
  
  has_many :word_items
  accepts_nested_attributes_for :word_items
    
  scope :with_words, includes(:word_items)
  scope :edit_to_define, with_words
  scope :edit_to_reveal_textual, with_words.merge(WordItem.ro_textual)
  scope :edit_to_reveal_graphical, with_words.merge(WordItem.ro_graphical)
  scope :ro_textual, edit_to_reveal_textual.readonly
  scope :ro_graphical, edit_to_reveal_graphical.readonly
  scope :index_detail, select(
    [:bonus_word, :bonus_value, :created_at, :updated_at, :revealed, :actual_payout]
  )

  # For permutations that hit the bonus word, the bonus value affects whether the permutation 
  # is possible and what value it pays out at if so.  The bonus value is an unknown, so we track
  # the distribution of winners for all possibilities and report them separately.
  BONUS_OFFSETS = [22, 44, 66, 88]
  TRIPLE_MATCH_PAYOUT_OFFSET = 110;
  PAYOUT_LOOKUP = [
    # No Bonus, No Triple
    0, 0, 1, 2, 3, 4, 7, 9, 11, 14, 16, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $4 Bonus, No Triple
    2, 2, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $5 Bonus, No Triple
    3, 3, 17, 17, 4, 6, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $10] Bonus, No Triple
    4, 4, 17, 17, 6, 7, 8, 10, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $30 Bonus, No Triple
    8, 8, 17, 17, 17, 17, 9, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # No Bonus, With Triple
    17, 0, 17, 5, 6, 8, 10, 12, 13, 15, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $4 Bonus, With Triple
    17, 2, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $5 Bonus, With Triple
    17, 3, 17, 17, 7, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $10] Bonus, With Triple
    17, 4, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
    # $30 Bonus, No Triple
    17, 8, 17, 17, 17, 10, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17
  ]

  ALPHABET = 
    ["a", "b" ,"c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",  
     "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]

  LETTERS_PRESENT_PER_TICKET = 18
  LETTERS_ABSENT_PER_TICKET = 8
  FINAL_KNOWN_LETTER_INDEX = 17
  WORDS_PER_TICKET = 22
  NUM_BONUS_TIERS = 4
  EMPTY_ARRAY = []

  def recalculate
    parse_letter_sets if revealed != self[:last_calc_revealed]
    next_ticket = Array.new(LETTERS_PRESENT_PER_TICKET)

    (@num_unknowns..FINAL_KNOWN_LETTER_INDEX).each { |i| 
      next_ticket[i] = @known_letters[LETTERS_PRESENT_PER_TICKET-i-1] }
    (0..(@num_unknowns-1)).each { |i|
      next_ticket[i] = @unused_letters[LETTERS_ABSENT_PER_TICKET+i] }

    # CollectionTwiddler only manipulates the first K values of next_ticket,
    # and expects them to be populated with the last K values of unusedLetters.
    # K is equal to the number of unknown letters.  The remainder of the 18]
    # total letters used came from the record's persistent letter set. 
    permuteEngine = 
      ApplicationHelper::CollectionTwiddler.new(
        next_ticket, @unused_letters, @num_unknowns )

    @num_combos = 1        
    @payout_counters = Array.new(18, 0)
    calculate_payout_index(next_ticket)
    while permuteEngine.next do
      @num_combos += 1
      calculate_payout_index(next_ticket)
    end

    logger.debug( "#{bonus_value}, #{@num_unknown}, and #{@known_letters.size} yield possible #{@num_combos} tickets")
    
    set_payout_counters
  end

  def allocate_word_slots
    (1..WORDS_PER_TICKET).each {|i| 
      self.word_items.new(:x_coordinate  => 0, :y_coordinate => 0) }
  end

  private
  def ensure_calculation_if_dirty
    recalculate if revealed != self[:last_calc_revealed];
  end
  
  def parse_letter_sets
    @known_letters = revealed.nil? ? EMPTY_ARRAY : revealed.split(//)
    @unused_letters = ALPHABET - @known_letters
    @num_unknowns = @unused_letters.size - LETTERS_ABSENT_PER_TICKET

    @words_by_letter = Hash[]
    ALPHABET.each { |next_letter|
      @words_by_letter[next_letter] = [] 
    }
    word_items.each {|next_word|
      next_word.letters.each {|next_letter|
        @words_by_letter[next_letter] << next_word 
      }
    }
    
    bw = self[:bonus_word]
    @bonus_letters = bw.nil? ? EMPTY_ARRAY : bw.split(//).to_set
  end

  def calculate_payout_index(letter_combo)
    # Build a list of words where each word is listed once for each of its dependent letters 
    # included in the input ticket of type Array[Char].  Use groupBy to build a map from each
    # word to a list of its appearances, then replace those lists with their size to yield a map
    # from each word to the number of its required letters that are present.  This will be 
    # cross-checked against the "lettersPerWord" map to identify completed words.
    coverage = Hash[]
    no_bonus = 5

    # logger.debug( "Next_ticket: #{letter_combo.inspect}" )
    word_items.each {|w_item| coverage[w_item] = 0 }
    letter_combo.each {|letter|
      @words_by_letter[letter].each {|w_item| coverage[w_item] += 1 }

      # TODO: Benchmark hash inclusion check against a binary search
      no_bonus -= 1 if no_bonus > 0 and @bonus_letters.include?(letter)
    }

    payout_offset = 0
    triple_offset = 0
    coverage.each { |k,v| 
      if (v == k.letters.size) 
        payout_offset += 1
        triple_offset = TRIPLE_MATCH_PAYOUT_OFFSET if k.triple_letter_index >= 0
      end
    }
    payout_offset += triple_offset
    
    # Lookup Index == (hasTriple*bonusLevels*wordCount) + 
    #                 (hasBonus*bonusIndex*wordCount) + 
    #                 wordCount
    # Lookup Index calculation is equivalent to the derivation of the an
    # memory address offset after mapping a three dimensional array with
    # fixed size boundary constraints onto a linear memory region.  In this
    # case, the hypothetical array was allocated with a size of [1][5][22].
    # -- The first dimension is bounded by the number of words: 22
    #    Although every permutation with a match score > 10 is inherrently
    #    illegal, the pre-benchmark assumption is that not checking the
    #    match count will be optimal.  If not, this table may get resized
    #    as [1][5][10].
    # -- The second dimension account for the repetition of 22 match-count
    #    values times the number of possible bonus payouts.  There are
    #    five such values: 0, 4, 5, 10, and 30, which are assigned the
    #    coordinates 0..4.  Multiply the actual coordinate by 22 and
    #    add this to the match count
    # -- The third dimension is boolean--either a triple prize word was
    #    matched or no such word was matched.  The 5 bonus scores create
    #    a total of 110 cells numbered 0..109.  Let the first range be used
    #    to classify payouts without a tripling match, and use the next range
    #    from 110..219 to classify payouts with a tripling match in effect.
    #
    # As an added wrinkle, if the bonus value is not yet known, we have to
    # tabulate a counter once for each of the four possible prizes.  The
    # lambda methods accept an increment argument for this case when the
    # bonus has not been met.  When an unknown bonus is met, four different
    # payout values will get tabulated.  In order to avoid skewing the 
    # reported result, four idenitical counters must get incremented when
    # the bonus is not met in these circumstances.
    if bonus_value >= 0
      payout_index = 
        PAYOUT_LOOKUP[payout_offset + ((no_bonus > 0) ? 0 : BONUS_OFFSETS[bonus_value])]
      # logger.debug( "#{payout_index} for #{@payout_counters.inspect}" )
      @payout_counters[payout_index] += 1

      if @num_unknowns == 0
        self[:actual_payout] = payout_index
      end
      
      # if(payout_index == 17 || payout_index == 8) 
      #   if no_bonus == 0 
      #     logger.debug( "Hit payout tier of <#{payout_index}> on input of <#{letter_combo.inspect}> with bonus <#{bonus_value}> on <#{payout_offset}>" );
      #   else
      #     logger.debug( "Hit payout tier of <#{payout_index}> on input of <#{letter_combo.inspect}> without bonus on <#{payout_offset}>" );
      #   end
      # end
    elsif no_bonus == 0
      base_offset = triple_offset + match_offset
      BONUS_OFFSETS.each { |bonus_tier|
        @payout_counters[PAYOUT_LOOKUP[base_offset + bonus_tier]] += 1 }
        
      # BONUS_OFFSETS.each { |bonus_tier|
      #   payout_index = PAYOUT_LOOKUP[base_offset + bonus_tier]
      #   if(payout_index == 17 || payout_index == 8) 
      #     logger.debug( "Hit payout tier of <#{payout_index}> on input of <#{letter_combo.inspect}> with bonus <#{bonus_tier}> on <#{payout_offset}>" );
      #   end
      # }
    else
      @payout_counters[PAYOUT_LOOKUP[base_offset]] += 4

      payout_index = PAYOUT_LOOKUP[base_offset + bonus_tier]
      # if(payout_index == 17 || payout_index == 8) 
      #   logger.debug( "Hit payout tier of <#{payout_index}> on input of <#{letter_combo.inspect}> without bonus on <#{payout_offset}>" )
      # end
    end
  end
  
  def clear_payout_counters
    self[:pays00] = self[:pays01] = self[:pays02] = self[:pays03] = self[:pays04] = self[:pays05] = 0
    self[:pays06] = self[:pays07] = self[:pays08] = self[:pays09] = self[:pays10] = self[:pays11] = 0
    self[:pays12] = self[:pays13] = self[:pays14] = self[:pays15] = self[:pays16] = self[:pays17] = 0
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
    self[:last_calc_revealed] = revealed
  end
end
