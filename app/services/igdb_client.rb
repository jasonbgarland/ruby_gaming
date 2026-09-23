# IgdbClient authenticates with Twitch (IGDB's OAuth provider) using the
# client-credentials flow, caches the resulting access token, and queries
# IGDB's /games endpoint using Apicalypse — IGDB's own query DSL (not a
# Ruby thing; a text-based query syntax specific to IGDB's API), exposing:
#
#   #search(query, limit:) — text search
#   #find(igdb_id)         — lookup by exact IGDB id
#
# Both return normalized IgdbClient::Game value objects:
#
#   igdb_id, name, cover_image_id, cover_url, summary, release_date,
#   platforms (Array<String>), genres (Array<String>)
#
# This client is standalone and not yet wired into the app.
#
# HTTP seam: only #fetch_token! and #games_request reference Net::HTTP.
# Every other method deals in plain Ruby values, so a future move to
# another HTTP library (e.g. Faraday) is contained to those two methods.
require "net/http"
require "json"
require "digest"

class IgdbClient
  TOKEN_URL = URI("https://id.twitch.tv/oauth2/token")
  GAMES_URL = URI("https://api.igdb.com/v4/games")
  COVER_URL_TEMPLATE = "https://images.igdb.com/igdb/image/upload/t_cover_big/%s.jpg"
  DEFAULT_LIMIT = 20
  SEARCH_FIELDS = "id,name,summary,first_release_date,cover.image_id,platforms.name,genres.name"
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10
  TOKEN_EXPIRY_MARGIN = 300

  Error = Class.new(StandardError)
  ConfigurationError = Class.new(Error)
  AuthenticationError = Class.new(Error)
  RequestError = Class.new(Error)
  ResponseError = Class.new(Error)

  Game = Data.define(
    :igdb_id,
    :name,
    :cover_image_id,
    :cover_url,
    :summary,
    :release_date,
    :platforms,
    :genres
  )

  def initialize(
    client_id: Rails.application.credentials.dig(:igdb, :client_id),
    client_secret: Rails.application.credentials.dig(:igdb, :client_secret),
    cache: Rails.cache
  )
    if client_id.blank? || client_secret.blank?
      raise ConfigurationError, "IgdbClient requires client_id and client_secret"
    end

    @client_id = client_id
    @client_secret = client_secret
    @cache = cache
  end

  def search(query, limit: DEFAULT_LIMIT)
    return [] if query.blank?

    body = apicalypse_query(query, limit)
    perform_games_request(body).first(limit)
  end

  # Looks up a single game by its IGDB id (not a text search). Returns nil
  # if IGDB has no game with that id.
  def find(igdb_id)
    return nil if igdb_id.blank?

    body = apicalypse_id_query(igdb_id)
    perform_games_request(body).first
  end

  private

  def perform_games_request(body)
    retried = false

    loop do
      response = games_request(body)
      code = response.code.to_i

      case code
      when 200..299
        return parse_games(response.body)
      when 401
        if retried
          raise AuthenticationError, "IGDB rejected the request twice (401)"
        end

        retried = true
        invalidate_token!
        next
      else
        raise RequestError, "IGDB request failed with status #{code}: #{truncate(response.body)}"
      end
    end
  end

  def access_token
    @cache.read(token_cache_key) || fetch_token!
  end

  def fetch_token!
    http = Net::HTTP.new(TOKEN_URL.host, TOKEN_URL.port)
    http.use_ssl = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Post.new(TOKEN_URL)
    request.set_form_data(
      "client_id" => @client_id,
      "client_secret" => @client_secret,
      "grant_type" => "client_credentials"
    )

    response = http.request(request)
    code = response.code.to_i

    unless (200..299).cover?(code)
      raise AuthenticationError, "Twitch token request failed with status #{code}: #{truncate(response.body)}"
    end

    payload = JSON.parse(response.body)
    token = payload["access_token"]
    expires_in = payload["expires_in"].to_i

    ttl = [ expires_in - TOKEN_EXPIRY_MARGIN, 60 ].max
    @cache.write(token_cache_key, token, expires_in: ttl)
    token
  end

  def invalidate_token!
    @cache.delete(token_cache_key)
  end

  def games_request(body)
    http = Net::HTTP.new(GAMES_URL.host, GAMES_URL.port)
    http.use_ssl = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Post.new(GAMES_URL)
    request["Client-ID"] = @client_id
    request["Authorization"] = "Bearer #{access_token}"
    request["Accept"] = "application/json"
    request["Content-Type"] = "text/plain"
    request.body = body

    http.request(request)
  end

  def apicalypse_query(query, limit)
    <<~QUERY
      fields #{SEARCH_FIELDS};
      search "#{escape(query)}";
      limit #{limit};
    QUERY
  end

  def apicalypse_id_query(igdb_id)
    <<~QUERY
      fields #{SEARCH_FIELDS};
      where id = #{Integer(igdb_id)};
    QUERY
  end

  def escape(query)
    query.gsub("\\", "\\\\\\\\").gsub('"', '\"')
  end

  def parse_games(response_body)
    rows = JSON.parse(response_body)

    unless rows.is_a?(Array)
      raise ResponseError, "expected a JSON array of games"
    end

    rows.filter_map { |row| normalize(row) }
  rescue JSON::ParserError => e
    raise ResponseError, "could not parse IGDB response: #{e.message}"
  end

  def normalize(row)
    return nil unless row.is_a?(Hash)

    igdb_id = row["id"]
    return nil unless igdb_id.is_a?(Integer)

    cover_image_id = row.dig("cover", "image_id")
    release_epoch = row["first_release_date"]

    Game.new(
      igdb_id: igdb_id,
      name: row["name"],
      cover_image_id: cover_image_id,
      cover_url: cover_image_id ? format(COVER_URL_TEMPLATE, cover_image_id) : nil,
      summary: row["summary"],
      release_date: release_epoch ? Time.at(release_epoch).utc.to_date : nil,
      platforms: Array(row["platforms"]).filter_map { |p| p["name"] if p.is_a?(Hash) },
      genres: Array(row["genres"]).filter_map { |g| g["name"] if g.is_a?(Hash) }
    )
  end

  def token_cache_key
    "igdb/access_token/#{Digest::SHA256.hexdigest(@client_id)[0, 16]}"
  end

  def truncate(str, length: 200)
    str.to_s.truncate(length)
  end
end
