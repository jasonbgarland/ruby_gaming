class Game < ApplicationRecord
  REFRESH_INTERVAL = 24.hours

  has_many :collection_games, dependent: :destroy
  has_many :collections, through: :collection_games
  has_many :game_companies, dependent: :destroy
  has_many :companies, through: :game_companies

  validates :igdb_id, presence: true, uniqueness: true
  validates :name, presence: true

  # Local cache lookup: returns a fresh Game row for the given igdb_id,
  # fetching/upserting from IGDB when the row is missing or stale
  def self.find_or_refresh(igdb_id, client: IgdbClient.new)
    game = find_by(igdb_id: igdb_id)
    return game if game && !game.stale?

    remote_game = client.find(igdb_id)
    return game unless remote_game

    upsert_from_igdb(remote_game)
  end

  def self.upsert_from_igdb(igdb_game)
    game = find_or_initialize_by(igdb_id: igdb_game.igdb_id)
    game.assign_attributes(
      name: igdb_game.name,
      cover_image_id: igdb_game.cover_image_id,
      cover_url: igdb_game.cover_url,
      summary: igdb_game.summary,
      first_release_date: igdb_game.release_date,
      platforms: igdb_game.platforms,
      genres: igdb_game.genres,
      igdb_url: igdb_game.igdb_url,
      slug: igdb_game.slug,
      game_type: igdb_game.game_type,
      game_modes: igdb_game.game_modes,
      themes: igdb_game.themes,
      age_ratings: igdb_game.age_ratings,
      refreshed_at: Time.current,
    )
    game.save!
    game
  end

  def stale?
    refreshed_at.nil? || refreshed_at < REFRESH_INTERVAL.ago
  end
end
