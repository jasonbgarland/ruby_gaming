class AddIgdbDetailsToGames < ActiveRecord::Migration[8.1]
  def change
    change_table :games, bulk: true do |t|
      t.string :igdb_url
      t.string :slug
      t.string :game_type
      t.string :game_modes, array: true, null: false, default: []
      t.string :themes, array: true, null: false, default: []
      t.string :age_ratings, array: true, null: false, default: []
    end
  end
end
