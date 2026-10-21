# Demo data: IGDB's top 100 games (db/seeds/games.yml, fetched once, so seeding
# needs no IGDB credentials) plus a demo user with a few populated collections.
# Safe to run repeatedly: everything is found by a natural key and updated.
#
#   bin/rails db:seed
#
# The demo password is public (it's in the README), so never seed production.
abort "db:seed creates a demo user with a public password; refusing to run in production." if Rails.env.production?

demo_user = {
  email_address: "demo@example.com",
  username: "demo",
  first_name: "Demo",
  last_name: "User",
  password: "demo-password-123"
}

# Collection title => [description, [[igdb_id, platform], ...]]. Platforms are
# names from each game's IGDB platform list (CollectionGame checks this).
demo_collections = {
  "All-time favourites" => [
    "Classics worth replaying.",
    [
      [ 1802, "Super Nintendo Entertainment System" ],   # Chrono Trigger
      [ 1103, "Super Nintendo Entertainment System" ],   # Super Metroid
      [ 1029, "Nintendo 64" ],                           # Ocarina of Time
      [ 233, "PC (Microsoft Windows)" ],                 # Half-Life 2
      [ 72, "PC (Microsoft Windows)" ],                  # Portal 2
      [ 379, "PlayStation 2" ],                          # Metal Gear Solid 3
      [ 481, "PlayStation 2" ],                          # Silent Hill 2
      [ 2207, "PlayStation 2" ]                          # Shadow of the Colossus
    ]
  ],
  "Currently playing" => [
    "What's on the console right now.",
    [
      [ 119171, "PC (Microsoft Windows)" ],              # Baldur's Gate III
      [ 119133, "PlayStation 5" ],                       # Elden Ring
      [ 305152, "PlayStation 5" ],                       # Clair Obscur: Expedition 33
      [ 115289, "Nintendo Switch" ]                      # Hollow Knight: Silksong
    ]
  ],
  "Wishlist" => [
    "Next up.",
    [
      [ 119388, "Nintendo Switch" ],                     # Zelda: Tears of the Kingdom
      [ 113112, "Nintendo Switch" ],                     # Hades
      [ 11737, "PC (Microsoft Windows)" ],               # Outer Wilds
      [ 75235, "PlayStation 5" ],                        # Ghost of Tsushima
      [ 298526, "Xbox Series X|S" ]                      # Kingdom Come: Deliverance II
    ]
  ]
}

to_igdb_game = lambda do |row|
  cover_image_id = row["cover_image_id"]
  IgdbClient::Game.new(
    igdb_id: row["igdb_id"],
    name: row["name"],
    cover_image_id: cover_image_id,
    cover_url: cover_image_id && format(IgdbClient::COVER_URL_TEMPLATE, cover_image_id),
    summary: row["summary"],
    release_date: row["release_date"] && Date.parse(row["release_date"].to_s),
    platforms: row["platforms"],
    genres: row["genres"],
    igdb_url: row["igdb_url"],
    slug: row["slug"],
    game_type: row["game_type"],
    game_modes: row["game_modes"],
    themes: row["themes"],
    companies: row["companies"].map { |c| c.transform_keys(&:to_sym) },
    age_ratings: row["age_ratings"]
  )
end

games = YAML.load_file(Rails.root.join("db/seeds/games.yml")).map do |row|
  Game.upsert_from_igdb(to_igdb_game.call(row))
end.index_by(&:igdb_id)

user = User.find_or_initialize_by(email_address: demo_user[:email_address])
user.update!(demo_user)

demo_collections.each do |title, (description, entries)|
  collection = user.collections.find_or_initialize_by(title: title)
  collection.update!(description: description)

  entries.each do |igdb_id, platform|
    collection.collection_games.find_or_create_by!(game: games.fetch(igdb_id), platform: platform)
  end
end

puts "Seeded #{games.size} games and the demo user (#{demo_user[:email_address]})."
