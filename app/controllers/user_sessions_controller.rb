class UserSessionsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = authenticate_user
    @user ? handle_successful_login : handle_failed_login
  end

  def destroy
    forget_me!
    logout
    redirect_to root_path, status: :see_other, alert: t('notices.logout_success')
  end

  private

  # ユーザー認証
  def authenticate_user
    login(params[:email], params[:password])
  end

  # ログイン成功時の処理
  def handle_successful_login
    remember_me! if params[:remember_me] == "1"
    redirect_back_or_to match_infos_path, notice: t('notices.login_success')
  end

  # ログイン失敗時の処理
  def handle_failed_login
    @user = User.new(email: params[:email])
    @user.errors.add(:base, t('notices.invalid_login'))
    render :new, status: :unprocessable_entity
  end
end
