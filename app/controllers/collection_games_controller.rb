class CollectionGamesController < ApplicationController
  before_action :set_collection

  def create
    unless params[:igdb_id].to_s.match?(/\A\d+\z/)
      redirect_back_to_collection alert: "Invalid game." and return
    end

    game = Game.find_or_refresh(params[:igdb_id])
    unless game
      redirect_back_to_collection alert: "Couldn't find that game on IGDB." and return
    end

    collection_game = @collection.collection_games.build(game: game, platform: params[:platform])
    if collection_game.save
      redirect_back_to_collection notice: "Added #{game.name} (#{collection_game.platform}) to #{@collection.title}."
    else
      redirect_back_to_collection alert: collection_game.errors.full_messages.to_sentence
    end
  end

  def destroy
    collection_game = @collection.collection_games.find(params[:id])
    collection_game.destroy
    redirect_to @collection, notice: "Removed #{collection_game.game.name} (#{collection_game.platform}).", status: :see_other
  end

  private
    # Keeps the search query in the URL so the results are still on screen.
    def redirect_back_to_collection(flash_options)
      redirect_to collection_path(@collection, q: params[:q]), **flash_options
    end

    # Same ownership scoping as CollectionsController: another user's
    # collection id raises RecordNotFound, which Rails renders as a 404.
    def set_collection
      @collection = Current.user.collections.find(params[:collection_id])
    end
end
