class WordItem < ActiveRecord::Base
  attr_accessible :crossword, :is_horizontal, :text_value, :x_coordinate, :y_coordinate, :triple_letter_index

  # after_initialize :parse_letters

  belongs_to :crossword

  default_scope order("id ASC")
  scope :ro_graphical, readonly()
  scope :ro_textual,
    select( [:crossword_id, :text_value, :triple_letter_index] )
      
  def letters 
    if @letters.nil? || @letters.size == 0
      parse_letters
    end

    return @letters
  end
  
  private
  def parse_letters
    @letters = text_value.downcase.split(//).to_set
  end
end
