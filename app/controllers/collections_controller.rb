class CollectionsController < ApplicationController
  def index
    @collections = Current.user.collections.order(:title)
  end

  def show
    @collection = Current.user.collections.find(params[:id])
    @collection_games = @collection.collection_games.includes(:game).order(:created_at)
  end
end
