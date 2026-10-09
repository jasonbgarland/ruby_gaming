class GamesController < ApplicationController
  def search
    @query = params[:q]
    @results = @query.present? ? IgdbClient.new.search(@query) : []
  end

  # The :id is the IGDB id, so a search result can link here before the game
  # has been saved locally; find_or_refresh fetches and saves it on demand.
  def show
    raise ActiveRecord::RecordNotFound unless params[:id].to_s.match?(/\A\d+\z/)

    @game = Game.find_or_refresh(params[:id]) or raise ActiveRecord::RecordNotFound
    @collection_games = CollectionGame.where(game: @game, collection: Current.user.collections)
      .includes(:collection).references(:collection).order("collections.title", :platform)
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
