# A user's written review of a game: one per user per game, any game (no
# collection needed). Text only. A "short" review is a quick take (up to 280
# characters, title optional) shown as a card; a "long" one is a fuller piece
# (up to 1000 characters) and needs a title.
class Review < ApplicationRecord
  KINDS = %w[ short long ].freeze
  BODY_LIMITS = { "short" => 280, "long" => 1000 }.freeze
  TITLE_LIMIT = 100

  belongs_to :user
  belongs_to :game
  has_many :reports, dependent: :destroy

  scope :short, -> { where(kind: "short") }
  scope :visible, -> { where(hidden: false) }
  # The moderator's to-do list: reviews with an open report, and hidden ones
  # whose author has edited them since (awaiting a second look). Once a
  # moderator decides, a review leaves the list.
  scope :needing_attention, -> { where(awaiting_review: true).or(where(id: Report.select(:review_id))) }
  # Hidden and decided: not in the to-do list, but listed so it can be restored.
  # (A hidden review can't be reported, so it has no open reports.)
  scope :hidden_and_settled, -> { where(hidden: true, awaiting_review: false) }

  # Editing a hidden review's text sends it back to the moderators.
  before_update :await_review, if: :edited_while_hidden?

  validates :kind, inclusion: { in: KINDS }
  validates :body, presence: true
  validates :body, length: { maximum: ->(review) { BODY_LIMITS.fetch(review.kind, BODY_LIMITS["long"]) } }
  validates :title, presence: true, if: :long?
  validates :title, length: { maximum: TITLE_LIMIT }
  validates :game_id, uniqueness: { scope: :user_id, message: "has already been reviewed" }

  # Hiding is the moderator's decision, so the reports behind it are cleared
  # and the review leaves the to-do list.
  def hide!
    transaction do
      update!(hidden: true, awaiting_review: false)
      dismiss_reports!
    end
  end

  # Unhiding is the verdict that the review is fine.
  def restore!
    transaction do
      update!(hidden: false, awaiting_review: false)
      dismiss_reports!
    end
  end

  # The moderator looked at an edited hidden review and it stays hidden.
  def keep_hidden!
    transaction do
      update!(awaiting_review: false)
      dismiss_reports!
    end
  end

  def dismiss_reports!
    reports.destroy_all
  end

  def short?
    kind == "short"
  end

  def long?
    kind == "long"
  end

  private

  def edited_while_hidden?
    hidden? && !hidden_changed? && (body_changed? || title_changed? || kind_changed?)
  end

  def await_review
    self.awaiting_review = true
  end
end
