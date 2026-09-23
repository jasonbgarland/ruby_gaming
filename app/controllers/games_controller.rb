class GamesController < ApplicationController
  def search
    @query = params[:q]
    @results = @query.present? ? IgdbClient.new.search(@query) : []
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
