class Game < ApplicationRecord
  REFRESH_INTERVAL = 24.hours

  has_many :collection_games, dependent: :destroy
  has_many :collections, through: :collection_games
  has_many :game_companies, dependent: :destroy
  has_many :companies, through: :game_companies

  validates :igdb_id, presence: true, uniqueness: true
  validates :name, presence: true

  # Local cache lookup: returns a fresh Game row for the given igdb_id,
  # fetching/upserting from IGDB when the row is missing or stale. If IGDB
  # can't be reached (no credentials, network or API failure), a stale row is
  # served as-is; with no row at all there is nothing to serve, so it raises.
  # The client is built inside the method (not as a default argument) so a
  # missing-credentials error is raised where the rescue can see it.
  def self.find_or_refresh(igdb_id, client: nil)
    game = find_by(igdb_id: igdb_id)
    return game if game && !game.stale?

    remote_game = (client || IgdbClient.new).find(igdb_id)
    return game unless remote_game

    upsert_from_igdb(remote_game)
  rescue IgdbClient::Error => e
    raise unless game

    Rails.logger.warn("IGDB refresh failed for #{igdb_id}, serving cached row: #{e.class}: #{e.message}")
    game
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
    transaction do
      game.save!
      game.sync_companies(igdb_game.companies)
    end
    game
  end

  # Makes our game_companies rows match IGDB's list. Each company gets one row
  # per role (developer, publisher) that IGDB marks true. Rows for roles IGDB
  # no longer lists are deleted, so a refresh can't leave old data behind.
  def sync_companies(entries)
    wanted = entries.flat_map do |entry|
      company = Company.find_or_create_by_name!(entry[:name])
      GameCompany::ROLES.select { |role| entry[role.to_sym] }.map { |role| [ company.id, role ] }
    end.uniq

    existing = game_companies.to_a
    existing.reject { |gc| wanted.include?([ gc.company_id, gc.role ]) }.each(&:destroy!)
    (wanted - existing.map { |gc| [ gc.company_id, gc.role ] }).each do |company_id, role|
      game_companies.create!(company_id: company_id, role: role)
    end
  end

  # Names of the companies with the given role ("developer" or "publisher"),
  # sorted by name. Filters in Ruby so one eager load serves both roles.
  def company_names(role)
    game_companies.includes(:company).select { |gc| gc.role == role }.map { |gc| gc.company.name }.sort
  end

  def stale?
    refreshed_at.nil? || refreshed_at < REFRESH_INTERVAL.ago
  end
end
