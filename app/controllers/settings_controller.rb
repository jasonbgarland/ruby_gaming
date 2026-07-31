class SettingsController < ApplicationController
  def show
    @user = Current.user
  end

  def update
    @user = Current.user
    if @user.update(profile_params)
      redirect_to settings_path, notice: "Your settings have been updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    @user = Current.user

    if params.dig(:user, :password_challenge).blank?
      @user.errors.add(:password_challenge, "can't be blank")
      render :show, status: :unprocessable_entity
      return
    end

    if @user.update(password_change_params)
      redirect_to settings_path, notice: "Your password has been updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def profile_params
      params.require(:user).permit(:first_name, :last_name, :username, :email_address)
    end

    def password_change_params
      params.require(:user).permit(:password_challenge, :password, :password_confirmation)
    end
end
