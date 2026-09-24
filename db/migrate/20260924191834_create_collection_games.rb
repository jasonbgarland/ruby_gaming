class CreateCollectionGames < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_games do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.string :platform, null: false

      t.timestamps
    end

    add_index :collection_games, [ :collection_id, :game_id, :platform ], unique: true, name: "index_collection_games_on_collection_game_platform"
  end
end
