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

ActiveRecord::Schema[8.1].define(version: 2026_06_19_000002) do
  create_table "analyses", force: :cascade do |t|
    t.datetime "accessed_at"
    t.datetime "computed_at"
    t.datetime "created_at", null: false
    t.string "doi", null: false
    t.integer "global_score"
    t.string "grade"
    t.string "locale", default: "en", null: false
    t.text "payload"
    t.datetime "updated_at", null: false
    t.index ["doi", "locale"], name: "index_analyses_on_doi_and_locale", unique: true
  end
end
