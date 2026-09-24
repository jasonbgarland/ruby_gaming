class Collection < ApplicationRecord
  belongs_to :user
  has_many :collection_games, dependent: :destroy
  has_many :games, through: :collection_games

  validates :title, presence: true, uniqueness: { scope: :user_id }
end
