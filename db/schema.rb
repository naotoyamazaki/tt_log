# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_02_17_093625) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "games", force: :cascade do |t|
    t.bigint "match_info_id"
    t.integer "game_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["match_info_id"], name: "index_games_on_match_info_id"
  end

  create_table "match_infos", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "player_id", null: false
    t.bigint "opponent_id", null: false
    t.date "match_date"
    t.string "match_name"
    t.text "memo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "advice"
    t.index ["opponent_id"], name: "index_match_infos_on_opponent_id"
    t.index ["player_id"], name: "index_match_infos_on_player_id"
    t.index ["user_id"], name: "index_match_infos_on_user_id"
  end

  create_table "players", force: :cascade do |t|
    t.string "player_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "scores", force: :cascade do |t|
    t.bigint "match_info_id", null: false
    t.bigint "game_id"
    t.integer "score"
    t.integer "lost_score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "batting_style", null: false
    t.index ["game_id"], name: "index_scores_on_game_id"
    t.index ["match_info_id"], name: "index_scores_on_match_info_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "crypted_password"
    t.string "salt"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_token_expires_at"
    t.datetime "reset_password_email_sent_at"
    t.integer "access_count_to_reset_password_page", default: 0
    t.string "remember_me_token"
    t.datetime "remember_me_token_expires_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "games", "match_infos"
  add_foreign_key "match_infos", "players"
  add_foreign_key "match_infos", "players", column: "opponent_id"
  add_foreign_key "match_infos", "users"
  add_foreign_key "scores", "games"
  add_foreign_key "scores", "match_infos"
end
