class SessionsController < ApplicationController
  # Rate limiting's default `store:` (the controller's `cache_store`) is
  # resolved once, at class-load time, from whatever `Rails.cache` happened
  # to be at that moment -- reassigning `Rails.cache` afterwards (e.g. in
  # tests) has no effect on it. This tiny indirection instead delegates to
  # whatever `Rails.cache` currently is on every call, so the rate limit
  # keeps working exactly as before in dev/production, while remaining
  # swappable for tests (see scenario 36 / test_login_rate_limited).
  module DynamicRateLimitStore
    def self.increment(...)
      Rails.cache.increment(...)
    end
  end

  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, store: DynamicRateLimitStore,
    with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    identifier = params[:identifier].to_s.strip.downcase
    if user = User.find_by("lower(email_address) = :v OR lower(username) = :v", v: identifier)&.authenticate(params[:password])
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another username/email or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
