class GamesController < ApplicationController
  # How many short-review cards the game page's row shows (newest first);
  # "See all reviews" has the rest.
  SHORT_REVIEWS_SHOWN = 12

  def search
    @query = params[:q]
    @results = @query.present? ? IgdbClient.new.search(@query) : []
  end

  # The :id is the IGDB id, so a search result can link here before the game
  # has been saved locally; find_or_refresh fetches and saves it on demand.
  def show
    raise ActiveRecord::RecordNotFound unless params[:id].to_s.match?(/\A\d+\z/)

    @game = Game.find_or_refresh(params[:id]) or raise ActiveRecord::RecordNotFound
    @collections = Current.user.collections.order(:title)
    @rating = @game.rating_for(Current.user)
    @my_review = @game.review_for(Current.user)
    @short_reviews = @game.reviews.short.includes(:user).order(created_at: :desc).limit(SHORT_REVIEWS_SHOWN)
    @reviews_count = @game.reviews.count
    @collection_games = @game.entries_for(Current.user)
  end

  def create
    unless params[:igdb_id].to_s.match?(/\A\d+\z/)
      redirect_to games_search_path(q: params[:q]), alert: "Invalid game." and return
    end

    game = Game.find_or_refresh(params[:igdb_id])

    if game
      redirect_to games_search_path(q: params[:q]), notice: "Added #{game.name} to your games."
    else
      redirect_to games_search_path(q: params[:q]), alert: "Couldn't find that game on IGDB."
    end
  end
end
