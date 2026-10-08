class CollectionGame < ApplicationRecord
  belongs_to :collection
  belongs_to :game

  validates :platform, presence: true
  validates :game_id, uniqueness: {
    scope: [ :collection_id, :platform ],
    message: "has already been added on that platform"
  }
  validate :platform_supported_by_game, if: -> { game.present? && platform.present? }

  private

  # Refreshes the game from IGDB first (rather than checking the
  # possibly-stale local cache) so a Game row that hasn't been read in
  # the last 24h doesn't spuriously reject a platform IGDB actually has.
  def platform_supported_by_game
    refreshed_game = Game.find_or_refresh(game.igdb_id) || game
    return if refreshed_game.platforms.include?(platform)

    errors.add(:platform, "is not available for #{refreshed_game.name}")
  end
end
