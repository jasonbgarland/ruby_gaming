# The moderation page. The queue is the to-do list: reviews with an open
# report, and hidden reviews their author has edited. Below it are the hidden
# reviews already decided, so they can be restored. Admins only; anyone else
# gets a 404 so the page's existence isn't revealed. Every action sends you
# back here.
module Admin
  class ReviewsController < ApplicationController
    before_action :require_admin
    before_action :set_review, except: :index

    def index
      @queue = Review.needing_attention.includes(:game, :user, reports: :user).order(created_at: :desc)
      @hidden = Review.hidden_and_settled.includes(:game, :user).order(created_at: :desc)
    end

    def hide
      @review.hide!
      back_to_queue "Hid #{@review.user.username}'s review."
    end

    def restore
      @review.restore!
      back_to_queue "Restored #{@review.user.username}'s review."
    end

    def keep_hidden
      @review.keep_hidden!
      back_to_queue "Kept #{@review.user.username}'s review hidden."
    end

    def dismiss
      @review.dismiss_reports!
      back_to_queue "Dismissed the reports on #{@review.user.username}'s review."
    end

    private
      def require_admin
        raise ActiveRecord::RecordNotFound unless Current.user.admin?
      end

      def set_review
        @review = Review.find(params[:id])
      end

      def back_to_queue(notice)
        redirect_to admin_reviews_path, notice: notice, status: :see_other
      end
  end
end
