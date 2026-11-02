# A user's star rating of a game, stored as half-stars (1-10) so 4.5 stars is
# 9 and every value is a whole number. Separate from reviews: you can rate
# without writing anything.
class Rating < ApplicationRecord
  belongs_to :user
  belongs_to :game

  validates :rating_halves, presence: true,
                            numericality: { only_integer: true, in: 1..10 }
  validates :game_id, uniqueness: { scope: :user_id, message: "has already been rated" }

  def stars
    rating_halves / 2.0
  end
end
