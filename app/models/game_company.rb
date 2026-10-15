class GameCompany < ApplicationRecord
  ROLES = %w[developer publisher].freeze

  belongs_to :game
  belongs_to :company

  validates :role, inclusion: { in: ROLES }
  validates :company_id, uniqueness: { scope: [ :game_id, :role ] }
end
