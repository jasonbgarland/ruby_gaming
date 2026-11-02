class CreateRatings < ActiveRecord::Migration[8.1]
  def change
    create_table :ratings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.integer :rating_halves, null: false

      t.timestamps
    end

    add_index :ratings, [ :user_id, :game_id ], unique: true, name: "index_ratings_on_user_and_game"
    add_check_constraint :ratings, "rating_halves BETWEEN 1 AND 10", name: "ratings_rating_halves_range"
  end
end
