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

  validates :kind, inclusion: { in: KINDS }
  validates :body, presence: true
  validates :body, length: { maximum: ->(review) { BODY_LIMITS.fetch(review.kind, BODY_LIMITS["long"]) } }
  validates :title, presence: true, if: :long?
  validates :title, length: { maximum: TITLE_LIMIT }
  validates :game_id, uniqueness: { scope: :user_id, message: "has already been reviewed" }

  def short?
    kind == "short"
  end

  def long?
    kind == "long"
  end
end
