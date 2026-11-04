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

ActiveRecord::Schema[8.1].define(version: 2026_11_04_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "collection_games", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.datetime "created_at", null: false
    t.bigint "game_id", null: false
    t.string "platform", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id", "game_id", "platform"], name: "index_collection_games_on_collection_game_platform", unique: true
    t.index ["collection_id"], name: "index_collection_games_on_collection_id"
    t.index ["game_id"], name: "index_collection_games_on_game_id"
  end

  create_table "collections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "title"], name: "index_collections_on_user_id_and_title", unique: true
    t.index ["user_id"], name: "index_collections_on_user_id"
  end

  create_table "companies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_companies_on_lower_name", unique: true
  end

  create_table "game_companies", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "game_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_game_companies_on_company_id"
    t.index ["game_id", "company_id", "role"], name: "index_game_companies_on_game_company_role", unique: true
    t.index ["game_id"], name: "index_game_companies_on_game_id"
  end

  create_table "games", force: :cascade do |t|
    t.string "age_ratings", default: [], null: false, array: true
    t.string "cover_image_id"
    t.string "cover_url"
    t.datetime "created_at", null: false
    t.date "first_release_date"
    t.string "game_modes", default: [], null: false, array: true
    t.string "game_type"
    t.string "genres", default: [], null: false, array: true
    t.bigint "igdb_id", null: false
    t.string "igdb_url"
    t.string "name", null: false
    t.string "platforms", default: [], null: false, array: true
    t.datetime "refreshed_at", null: false
    t.string "slug"
    t.text "summary"
    t.string "themes", default: [], null: false, array: true
    t.datetime "updated_at", null: false
    t.index ["genres"], name: "index_games_on_genres", using: :gin
    t.index ["igdb_id"], name: "index_games_on_igdb_id", unique: true
    t.index ["name"], name: "index_games_on_name"
    t.index ["platforms"], name: "index_games_on_platforms", using: :gin
  end

  create_table "ratings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "game_id", null: false
    t.integer "rating_halves", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["game_id"], name: "index_ratings_on_game_id"
    t.index ["user_id", "game_id"], name: "index_ratings_on_user_and_game", unique: true
    t.index ["user_id"], name: "index_ratings_on_user_id"
    t.check_constraint "rating_halves >= 1 AND rating_halves <= 10", name: "ratings_rating_halves_range"
  end

  create_table "reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "reason", null: false
    t.bigint "review_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["review_id"], name: "index_reports_on_review_id"
    t.index ["user_id", "review_id"], name: "index_reports_on_user_and_review", unique: true
    t.index ["user_id"], name: "index_reports_on_user_id"
    t.check_constraint "reason::text = ANY (ARRAY['spam'::character varying, 'abusive'::character varying, 'spoiler'::character varying, 'other'::character varying]::text[])", name: "reports_reason_values"
  end

  create_table "reviews", force: :cascade do |t|
    t.boolean "awaiting_review", default: false, null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "game_id", null: false
    t.boolean "hidden", default: false, null: false
    t.string "kind", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["game_id"], name: "index_reviews_on_game_id"
    t.index ["user_id", "game_id"], name: "index_reviews_on_user_and_game", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
    t.check_constraint "kind::text = ANY (ARRAY['short'::character varying, 'long'::character varying]::text[])", name: "reviews_kind_values"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index "lower((username)::text)", name: "index_users_on_lower_username", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "collection_games", "collections"
  add_foreign_key "collection_games", "games"
  add_foreign_key "collections", "users"
  add_foreign_key "game_companies", "companies"
  add_foreign_key "game_companies", "games"
  add_foreign_key "ratings", "games"
  add_foreign_key "ratings", "users"
  add_foreign_key "reports", "reviews"
  add_foreign_key "reports", "users"
  add_foreign_key "reviews", "games"
  add_foreign_key "reviews", "users"
  add_foreign_key "sessions", "users"
end
