class PasswordResetsController < ApplicationController
  def new; end

  def edit
    @token = params[:id]
    @user = User.load_from_reset_password_token(params[:id])
    not_authenticated if @user.blank?
  end

  def create
    @user = User.find_by(email: params[:email])
    @user&.deliver_reset_password_instructions!
    redirect_to login_path, notice: t('notices.password_reset_sent')
  end

  def update
    @token = params[:id]
    @user = find_user_by_token

    return handle_invalid_user if @user.blank?

    update_password
  end

  private

  # update
  # トークンからユーザーを取得
  def find_user_by_token
    User.load_from_reset_password_token(params[:id])
  end

  # ユーザーが見つからない場合の処理
  def handle_invalid_user
    not_authenticated
  end

  # パスワードを更新
  def update_password
    @user.password_confirmation = params[:user][:password_confirmation]

    if @user.change_password(params[:user][:password])
      redirect_to login_path, notice: t('notices.password_reset_success')
    else
      render action: 'edit'
    end
  end
end
