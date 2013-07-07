class AddBoardToCrossword < ActiveRecord::Migration
  def change
    add_column :crosswords, :board, :string, :limit => 121, :null => false, :default => '_________________________________________________________________________________________________________________________'
  end
end
