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

ActiveRecord::Schema[8.0].define(version: 2025_09_20_113557) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "songs", force: :cascade do |t|
    t.string "artist", null: false
    t.string "title", null: false
    t.integer "release_year", null: false
    t.string "spotify_uuid", null: false
    t.string "qr_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["qr_token"], name: "index_songs_on_qr_token", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "spotify_uid"
    t.string "display_name"
    t.string "email"
    t.string "avatar_url"
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["spotify_uid"], name: "index_users_on_spotify_uid"
  end
end
