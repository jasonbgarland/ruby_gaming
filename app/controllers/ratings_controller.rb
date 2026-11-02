# One rating per user per game, so the route is a singular nested resource
# (/games/:game_id/rating) and the :game_id is the IGDB id, like the game page.
class RatingsController < ApplicationController
  before_action :set_game

  # Rating again changes the existing rating rather than failing the
  # uniqueness check, so the star form always posts here.
  def create
    rating = Current.user.ratings.find_or_initialize_by(game: @game)
    rating.rating_halves = params[:rating_halves]

    if rating.save
      redirect_to game_path(@game.igdb_id), notice: "Rated #{@game.name} #{helpers.stars_label(rating)}."
    else
      redirect_to game_path(@game.igdb_id), alert: rating.errors.full_messages.to_sentence
    end
  end

  def destroy
    Current.user.ratings.where(game: @game).destroy_all
    redirect_to game_path(@game.igdb_id), notice: "Cleared your rating of #{@game.name}.", status: :see_other
  end

  private
    # Only games already saved locally: you reach this from the game page,
    # which has just fetched the game. An unknown id is a 404.
    def set_game
      @game = Game.find_by!(igdb_id: params[:game_id])
    end
end
