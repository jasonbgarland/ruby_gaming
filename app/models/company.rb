class Company < ApplicationRecord
  has_many :game_companies, dependent: :destroy
  has_many :games, through: :game_companies

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
