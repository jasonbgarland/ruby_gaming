# A user's report of a review, for an admin to look at. The reason comes from a
# fixed list. One report per user per review; reporting your own review makes
# no sense, so that is refused too.
class Report < ApplicationRecord
  REASONS = {
    "spam" => "Spam",
    "abusive" => "Abusive or hateful",
    "spoiler" => "Spoiler not hidden",
    "other" => "Something else"
  }.freeze

  belongs_to :user
  belongs_to :review

  validates :reason, inclusion: { in: REASONS.keys }
  validates :review_id, uniqueness: { scope: :user_id, message: "has already been reported" }
  validate :not_own_review
  validate :not_hidden_review

  private

  # A hidden review has already been decided by a moderator.
  def not_hidden_review
    errors.add(:review, "is already hidden") if review&.hidden?
  end

  def not_own_review
    errors.add(:review, "can't be your own") if review && review.user_id == user_id
  end
end
