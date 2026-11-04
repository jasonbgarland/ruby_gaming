# Report a review (/games/:game_id/reviews/:review_id/report). The :game_id is
# the IGDB id, like the rest of the game routes. A review that is hidden from
# you can't be reported, since you can't see it: that is a 404.
class ReportsController < ApplicationController
  before_action :set_game
  before_action :set_review

  def create
    report = Current.user.reports.build(review: @review, reason: params[:reason])

    if report.save
      redirect_back_or_to game_reviews_path(@game.igdb_id), notice: "Thanks, a moderator will take a look."
    else
      redirect_back_or_to game_reviews_path(@game.igdb_id), alert: report.errors.full_messages.to_sentence
    end
  end

  private
    def set_game
      @game = Game.find_by!(igdb_id: params[:game_id])
    end

    def set_review
      @review = @game.reviews_visible_to(Current.user).find(params[:review_id])
    end
end
