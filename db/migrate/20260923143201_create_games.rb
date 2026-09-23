class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.bigint :igdb_id, null: false
      t.string :name, null: false
      t.string :cover_image_id
      t.string :cover_url
      t.text :summary
      t.date :first_release_date
      t.string :platforms, array: true, null: false, default: []
      t.string :genres, array: true, null: false, default: []
      t.datetime :refreshed_at, null: false

      t.timestamps
    end

    add_index :games, :igdb_id, unique: true
    add_index :games, :name
    add_index :games, :platforms, using: :gin
    add_index :games, :genres, using: :gin
  end
end
