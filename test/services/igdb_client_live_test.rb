# Live smoke test for IgdbClient. Excluded from the default `bin/rails test`
# run; opt in explicitly once real IGDB/Twitch credentials are configured
# via `bin/rails credentials:edit` (igdb.client_id / igdb.client_secret)
# and outbound network access is available:
#
#   RUN_IGDB_INTEGRATION=1 bin/rails test test/services/igdb_client_live_test.rb
#
require "test_helper"

class IgdbClientLiveTest < ActiveSupport::TestCase
  setup do
    skip "Set RUN_IGDB_INTEGRATION=1 to run the live IGDB smoke test" unless ENV["RUN_IGDB_INTEGRATION"].present?
    WebMock.allow_net_connect!
  end

  teardown do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  test "live search returns results" do
    client = IgdbClient.new(cache: Rails.cache)

    games = client.search("zelda")

    assert games.size >= 1
    game = games.first
    assert_kind_of Integer, game.igdb_id
    assert game.name.present?
  end
end
