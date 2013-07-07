# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130623122731) do

  create_table "crosswords", :force => true do |t|
    t.string   "bonus_word",         :limit => 5,   :default => "",                                                                                                                          :null => false
    t.integer  "bonus_value",                       :default => -1,                                                                                                                          :null => false
    t.string   "revealed",           :limit => 18,  :default => "",                                                                                                                          :null => false
    t.string   "last_calc_revealed", :limit => 18,  :default => "",                                                                                                                          :null => false
    t.integer  "actual_prize"
    t.integer  "pays00",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays01",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays02",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays03",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays04",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays05",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays06",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays07",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays08",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays09",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays10",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays11",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays12",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays13",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays14",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays15",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays16",                            :default => 0,                                                                                                                           :null => false
    t.integer  "pays17",                            :default => 0,                                                                                                                           :null => false
    t.datetime "created_at",                                                                                                                                                                 :null => false
    t.datetime "updated_at",                                                                                                                                                                 :null => false
    t.string   "board",              :limit => 121, :default => "_________________________________________________________________________________________________________________________", :null => false
  end

  create_table "word_items", :force => true do |t|
    t.integer "crossword_id",                                         :null => false
    t.string  "text_value",          :limit => 12, :default => "",    :null => false
    t.integer "x_coordinate",                      :default => -1,    :null => false
    t.integer "y_coordinate",                      :default => -1,    :null => false
    t.boolean "is_horizontal",                     :default => false
    t.integer "triple_letter_index",               :default => -1,    :null => false
  end

  add_index "word_items", ["crossword_id", "text_value"], :name => "index_word_items_on_crossword_id_and_text_value", :unique => true

end
