class UserSessionsController < ApplicationController
  def new; end

  def create
    @user = login(params[:email], params[:password])
    if @user
      redirect_back_or_to match_infos_path, notice: "ログインが完了しました"
    else
      render :new
    end
  end

  def destroy
    logout
    redirect_to root_path, status: :see_other, alert: "ログアウトしました"
  end
end
