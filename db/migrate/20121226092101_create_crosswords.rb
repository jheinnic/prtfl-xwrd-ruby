class CreateCrosswords < ActiveRecord::Migration
  def change
    create_table :crosswords do |t|
      t.string :bonus_word, :default => '', :limit => 5, :null => false
      t.decimal :bonus_value, :default => -1, :precision => 1, :scale => 0, :null => false
      t.string :revealed, :last_calc_revealed, :default => '', :limit => 18, :null => false
      t.decimal :actual_prize, :precision => 2, :scale => 0
      t.integer :pays00, :pays01, :pays02, :pays03, :pays04, :pays05, :pays06, :pays07, :pays08, :pays09, :pays10, :pays11, :pays12, :pays13, :pays14, :pays15, :pays16, :pays17, :default => 0, :null => false

      t.timestamps
    end
    
    create_table :word_items do |t|
      t.belongs_to :crossword, :null => false
      t.string :text_value, :default => '', :limit => 11, :null => false
      t.decimal :x_coordinate, :y_coordinate, :triple_letter_index, :default => -1, :precision => 2, :scale => 0, :null => false
      t.boolean :is_horizontal, :default => true, :null => false
    end
    
    add_index :word_items, [:crossword_id, :text_value], :unique => true
  end
end
