puts "hello"

def makeit 
	cw = Crossword.new( :bonus_word => "comet", :bonus_value => 1 )
	cw.word_items.clear
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 1, :triple_letter_index => 4,  :text_value => "nautilus"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 1, :triple_letter_index => 2,  :text_value => "rope"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 1, :triple_letter_index => 0,  :text_value => "button"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 1, :triple_letter_index => -1,  :text_value => "own"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 1, :triple_letter_index => -1,  :text_value => "paw"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 1, :triple_letter_index => -1,  :text_value => "twig"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 1, :triple_letter_index => -1,  :text_value => "act"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 1, :triple_letter_index => -1,  :text_value => "layering"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 1, :triple_letter_index => -1,  :text_value => "old"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 1, :triple_letter_index => -1,  :text_value => "fever"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 1, :triple_letter_index => -1,  :text_value => "exit"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 1, :triple_letter_index => -1,  :text_value => "path"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 0, :triple_letter_index => 4,  :text_value => "amuse"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 0, :triple_letter_index => -1,  :text_value => "squall"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 0, :triple_letter_index => -1,  :text_value => "ace"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 0, :triple_letter_index => -1,  :text_value => "kettle"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 0, :triple_letter_index => -1,  :text_value => "thaw"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 0, :triple_letter_index => -1,  :text_value => "piano"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 0, :triple_letter_index => -1,  :text_value => "long"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 0, :triple_letter_index => -1,  :text_value => "upgrade"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 0, :triple_letter_index => -1,  :text_value => "soup"
	cw.word_items.build :x_coordinate => 1, :y_coordinate => 2, :is_horizontal => 0, :triple_letter_index => -1,  :text_value => "snowshoes"
	
	puts "Before Save: #{cw.inspect}"
	cw.save
	puts "After Save: #{cw.inspect}"
	
  #cw.revealed = "nautilsogwbpxyzqjc"
  #cw.recalculate
  #puts cw.inspect
  #return cw

	#cw.revealed = "ehgqvdnliurtsbmf"
  #cw.recalculate
  #puts "After artificial case #1 #{cw.inspect}"
  
	#cw.revealed = "ehgqvdnliur"
  #cw.recalculate
  #puts "After artificial case #2 #{cw.inspect}"
	
	#cw.revealed = "tmlbfdeh"
  #cw.recalculate
  #puts "After selecting 8: #{cw.inspect}"

        # reveal_order = ['e', 'h', 'g', 'q', 'v', 'd', 'n', 'l', 'i', 'u', 'r', 't', 's', 'b', 'm', 'f', 'p', 'c']
        reveal_order = ['t', 'm', 'l', 'b', 'f', 'd', 'e', 'h', 'g', 'q', 'r', 'p', 'n', 'u', 's', 'i', 'v', 'c']
		
	reveal_order.each{ |next_letter|
        cw.revealed = "#{cw.revealed}#{next_letter}"
	  cw.recalculate
	  cw.save
	  puts "After revealing #{next_letter}: #{cw.inspect}"
	}

	return cw
end
