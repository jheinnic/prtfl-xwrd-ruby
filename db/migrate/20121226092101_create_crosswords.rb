class CreateCrosswords < ActiveRecord::Migration
  def change
    create_table :crosswords do |t|
      t.string :bonus_word, :default => '', :length => 5, :precision => 5, :null => false
      t.integer :bonus_value, :default => -1, :precision => 1, :null => false
      t.string :revealed, :default => '', :length => 18, :precision => 18, :null => false
      t.string :last_calc_revealed, :default => '', :length => 18, :precision => 18, :null => false
      t.integer :actual_prize
      t.integer :pays00, :default => 0, :null => false
      t.integer :pays01, :default => 0, :null => false
      t.integer :pays02, :default => 0, :null => false
      t.integer :pays03, :default => 0, :null => false
      t.integer :pays04, :default => 0, :null => false
      t.integer :pays05, :default => 0, :null => false
      t.integer :pays06, :default => 0, :null => false
      t.integer :pays07, :default => 0, :null => false
      t.integer :pays08, :default => 0, :null => false
      t.integer :pays09, :default => 0, :null => false
      t.integer :pays10, :default => 0, :null => false
      t.integer :pays11, :default => 0, :null => false
      t.integer :pays12, :default => 0, :null => false
      t.integer :pays13, :default => 0, :null => false
      t.integer :pays14, :default => 0, :null => false
      t.integer :pays15, :default => 0, :null => false
      t.integer :pays16, :default => 0, :null => false
      t.integer :pays17, :default => 0, :null => false

      t.timestamps
    end
    
    create_table :word_items do |t|
      t.belongs_to :crossword, :null => false
      t.string :text_value, :default => '', :length => 12, :precision => 12, :null => false
      t.integer :x_coordinate, :default => -1, :precision => 2, :null => false
      t.integer :y_coordinate, :default => -1, :precision => 2, :null => false
      t.boolean :is_horizontal, :default => true, :null => false
      t.integer :triple_letter_index, :default => -1, :precision => 2, :null => false
    end
    
    add_index :word_items, [:crossword_id, :text_value], :unique => true
  end
end
