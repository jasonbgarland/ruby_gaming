class AddAwaitingReviewToReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :reviews, :awaiting_review, :boolean, null: false, default: false
  end
end
