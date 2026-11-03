class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :title
      t.text :body, null: false

      t.timestamps
    end

    add_index :reviews, [ :user_id, :game_id ], unique: true, name: "index_reviews_on_user_and_game"
    add_check_constraint :reviews, "kind IN ('short', 'long')", name: "reviews_kind_values"
  end
end
