class Company < ApplicationRecord
  has_many :game_companies, dependent: :destroy
  has_many :games, through: :game_companies

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Companies match by name, ignoring case, because IGDB's client gives us no
  # company ids. The first spelling we saw is the one that is kept.
  def self.find_or_create_by_name!(name)
    where("lower(name) = ?", name.downcase).first || create!(name: name)
  end
end
