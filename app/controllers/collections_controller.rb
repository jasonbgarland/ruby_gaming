class CollectionsController < ApplicationController
  before_action :set_collection, only: %i[ show edit update destroy ]

  def index
    @collections = Current.user.collections.order(:title)
  end

  def show
    @collection_games = @collection.collection_games.includes(:game).order(:created_at)
    @query = params[:q]
    @results = @query.present? ? IgdbClient.new.search(@query) : []
  end

  def new
    @collection = Current.user.collections.build
  end

  def create
    @collection = Current.user.collections.build(collection_params)
    if @collection.save
      redirect_to @collection, notice: "Collection created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @collection.update(collection_params)
      redirect_to @collection, notice: "Collection updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @collection.destroy
    redirect_to collections_path, notice: "Collection deleted.", status: :see_other
  end

  private
    def set_collection
      @collection = Current.user.collections.find(params[:id])
    end

    def collection_params
      params.require(:collection).permit(:title, :description)
    end
end
