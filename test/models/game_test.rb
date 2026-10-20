require "test_helper"

class GameTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  FakeIgdbClient = Struct.new(:responses) do
    def find(igdb_id)
      unless responses.key?(igdb_id)
        raise "unexpected IgdbClient#find(#{igdb_id.inspect}) call"
      end

      responses.fetch(igdb_id)
    end
  end

  def fake_client(responses)
    FakeIgdbClient.new(responses)
  end

  def unused_client
    fake_client({})
  end

  def igdb_game(overrides = {})
    IgdbClient::Game.new(
      **{
        igdb_id: 1022,
        name: "The Legend of Zelda",
        cover_image_id: "abc123",
        cover_url: "https://images.igdb.com/igdb/image/upload/t_cover_big/abc123.jpg",
        summary: "An adventure.",
        release_date: Date.new(1986, 2, 21),
        platforms: [ "NES", "Switch" ],
        genres: [ "Adventure" ],
        igdb_url: nil,
        slug: nil,
        game_type: nil,
        game_modes: [],
        themes: [],
        companies: [],
        age_ratings: []
      }.merge(overrides)
    )
  end

  test "requires igdb_id" do
    game = Game.new(name: "Test")
    assert_not game.valid?
    assert_includes game.errors[:igdb_id], "can't be blank"
  end

  test "requires a unique igdb_id" do
    Game.create!(igdb_id: 1, name: "First", refreshed_at: Time.current)
    dup = Game.new(igdb_id: 1, name: "Second", refreshed_at: Time.current)

    assert_not dup.valid?
    assert_includes dup.errors[:igdb_id], "has already been taken"
  end

  test "requires a name" do
    game = Game.new(igdb_id: 1)
    assert_not game.valid?
    assert_includes game.errors[:name], "can't be blank"
  end

  test "stale? is true when never refreshed" do
    game = Game.new(refreshed_at: nil)
    assert game.stale?
  end

  test "stale? is true once past the refresh interval" do
    game = Game.new(refreshed_at: (Game::REFRESH_INTERVAL + 1.minute).ago)
    assert game.stale?
  end

  test "stale? is false within the refresh interval" do
    game = Game.new(refreshed_at: 1.hour.ago)
    assert_not game.stale?
  end

  test "upsert_from_igdb creates a new row from IGDB data" do
    game = Game.upsert_from_igdb(igdb_game)

    assert game.persisted?
    assert_equal 1022, game.igdb_id
    assert_equal "The Legend of Zelda", game.name
    assert_equal "abc123", game.cover_image_id
    assert_equal [ "NES", "Switch" ], game.platforms
    assert_equal [ "Adventure" ], game.genres
    assert_not game.stale?
  end

  test "upsert_from_igdb saves the static detail fields" do
    game = Game.upsert_from_igdb(igdb_game(
      igdb_url: "https://www.igdb.com/games/the-legend-of-zelda",
      slug: "the-legend-of-zelda",
      game_type: "Main Game",
      game_modes: [ "Single player" ],
      themes: [ "Fantasy", "Action" ],
      age_ratings: [ "ESRB E10+", "PEGI 7" ]
    )).reload

    assert_equal "https://www.igdb.com/games/the-legend-of-zelda", game.igdb_url
    assert_equal "the-legend-of-zelda", game.slug
    assert_equal "Main Game", game.game_type
    assert_equal [ "Single player" ], game.game_modes
    assert_equal [ "Fantasy", "Action" ], game.themes
    assert_equal [ "ESRB E10+", "PEGI 7" ], game.age_ratings
  end

  test "upsert_from_igdb overwrites the detail fields on refresh" do
    Game.upsert_from_igdb(igdb_game(themes: [ "Fantasy" ], game_type: "Main Game"))

    updated = Game.upsert_from_igdb(igdb_game(themes: [ "Action" ], game_type: nil)).reload

    assert_equal [ "Action" ], updated.themes
    assert_nil updated.game_type
  end

  test "upsert_from_igdb saves developers and publishers" do
    game = Game.upsert_from_igdb(igdb_game(companies: [
      { name: "Nintendo", developer: true, publisher: true },
      { name: "Capcom", developer: false, publisher: true }
    ]))

    roles = game.game_companies.includes(:company).map { |gc| [ gc.company.name, gc.role ] }
    assert_equal [ [ "Capcom", "publisher" ], [ "Nintendo", "developer" ], [ "Nintendo", "publisher" ] ], roles.sort
  end

  test "upsert_from_igdb reuses a company by name, ignoring case" do
    Game.upsert_from_igdb(igdb_game(companies: [ { name: "Nintendo", developer: true, publisher: false } ]))
    other = Game.upsert_from_igdb(igdb_game(
      igdb_id: 7, name: "Metroid",
      companies: [ { name: "NINTENDO", developer: true, publisher: false } ]
    ))

    assert_equal 1, Company.count
    assert_equal "Nintendo", other.companies.first.name
  end

  test "upsert_from_igdb replaces stale companies on refresh and is idempotent" do
    Game.upsert_from_igdb(igdb_game(companies: [
      { name: "Nintendo", developer: true, publisher: true }
    ]))
    Game.upsert_from_igdb(igdb_game(companies: [
      { name: "Nintendo", developer: true, publisher: false },
      { name: "Capcom", developer: false, publisher: true }
    ]))
    game = Game.upsert_from_igdb(igdb_game(companies: [
      { name: "Nintendo", developer: true, publisher: false },
      { name: "Capcom", developer: false, publisher: true }
    ]))

    roles = game.game_companies.includes(:company).map { |gc| [ gc.company.name, gc.role ] }
    assert_equal [ [ "Capcom", "publisher" ], [ "Nintendo", "developer" ] ], roles.sort
  end

  test "upsert_from_igdb updates the existing row for the same igdb_id" do
    Game.upsert_from_igdb(igdb_game)

    updated = Game.upsert_from_igdb(igdb_game(name: "Zelda: Renamed", platforms: [ "Switch" ]))

    assert_equal 1, Game.where(igdb_id: 1022).count
    assert_equal "Zelda: Renamed", updated.name
    assert_equal [ "Switch" ], updated.platforms
  end

  test "find_or_refresh returns the local row without hitting IGDB when fresh" do
    Game.upsert_from_igdb(igdb_game)

    game = Game.find_or_refresh(1022, client: unused_client)

    assert_equal "The Legend of Zelda", game.name
  end

  test "find_or_refresh refetches and updates a stale row" do
    game = Game.upsert_from_igdb(igdb_game)
    game.update!(refreshed_at: (Game::REFRESH_INTERVAL + 1.minute).ago)

    client = fake_client(1022 => igdb_game(name: "Zelda: Refreshed"))
    refreshed = Game.find_or_refresh(1022, client: client)

    assert_equal "Zelda: Refreshed", refreshed.name
    assert_not refreshed.stale?
  end

  test "find_or_refresh fetches from IGDB when no local row exists" do
    client = fake_client(1022 => igdb_game)

    game = Game.find_or_refresh(1022, client: client)

    assert_equal "The Legend of Zelda", game.name
  end

  test "find_or_refresh returns the stale local row when IGDB has no match" do
    game = Game.upsert_from_igdb(igdb_game)
    game.update!(refreshed_at: (Game::REFRESH_INTERVAL + 1.minute).ago)

    client = fake_client(1022 => nil)
    result = Game.find_or_refresh(1022, client: client)

    assert_equal game.id, result.id
  end

  test "find_or_refresh returns nil when nothing local and IGDB has no match" do
    client = fake_client(424_242 => nil)

    assert_nil Game.find_or_refresh(424_242, client: client)
  end
end
