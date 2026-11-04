class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :collections, dependent: :destroy
  has_many :ratings, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :reports, dependent: :destroy

  # The ids, among these reviews, that this user has reported (one query), so a
  # list can show "Reported" without a query per review.
  def reported_review_ids(reviews)
    reports.where(review_id: reviews.map(&:id)).pluck(:review_id)
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :username, presence: true,
                        length: { maximum: 20 },
                        format: { with: /\A[A-Za-z0-9_\- ]+\z/, message: "can only contain letters, numbers, hyphens, underscores, and spaces" },
                        uniqueness: { case_sensitive: false }
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP },
                             uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 8 }, allow_nil: true
end
