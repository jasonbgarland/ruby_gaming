# Reviews live under a game (/games/:game_id/reviews) and the :game_id is the
# IGDB id, like the game page and ratings. The index lists everyone's reviews;
# writing, editing and deleting only ever touch the signed-in user's own.
class ReviewsController < ApplicationController
  before_action :set_game
  before_action :set_review, only: %i[ edit update destroy ]

  def index
    @reviews = @game.reviews_visible_to(Current.user).includes(:user).order(created_at: :desc)
    @my_review = @game.review_for(Current.user)
    @reported_review_ids = Current.user.reported_review_ids(@reviews)
    @ratings_by_user = @game.ratings_by_user(@reviews.map(&:user_id))
  end

  # One review per user per game, so if you already have one, go edit it.
  def new
    existing = @game.review_for(Current.user)
    return redirect_to edit_game_review_path(@game.igdb_id, existing) if existing

    @review = @game.reviews.build(user: Current.user, kind: "short")
  end

  def create
    @review = @game.reviews.build(review_params.merge(user: Current.user))
    if @review.save
      redirect_to game_reviews_path(@game.igdb_id), notice: "Posted your review of #{@game.name}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @review.update(review_params)
      redirect_to game_reviews_path(@game.igdb_id), notice: "Updated your review of #{@game.name}."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # A hidden review can't be deleted: deleting it would also delete its
  # reports, and writing a new one would dodge the moderator's decision.
  def destroy
    if @review.hidden?
      return redirect_to game_reviews_path(@game.igdb_id),
        alert: "A moderator hid this review, so it can't be deleted. You can still edit it.",
        status: :see_other
    end

    @review.destroy
    redirect_to game_path(@game.igdb_id), notice: "Deleted your review of #{@game.name}.", status: :see_other
  end

  private
    # Only games already saved locally: you reach this from the game page,
    # which has just fetched the game. An unknown id is a 404.
    def set_game
      @game = Game.find_by!(igdb_id: params[:game_id])
    end

    # Looked up through the current user, so someone else's review is a 404.
    def set_review
      @review = Current.user.reviews.find_by!(game: @game, id: params[:id])
    end

    def review_params
      params.require(:review).permit(:kind, :title, :body)
    end
end
