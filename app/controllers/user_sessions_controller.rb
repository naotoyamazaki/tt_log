class UserSessionsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = login(params[:email], params[:password])
    if @user
      redirect_back_or_to match_infos_path, notice: "ログインが完了しました"
    else
      @user = User.new(email: params[:email])
      flash.now[:alert] = "メールアドレスまたはパスワードが正しくありません。"
      render :new
    end
  end

  def destroy
    logout
    redirect_to root_path, status: :see_other, alert: "ログアウトしました"
  end
end
