module UserSessionsHelper
  # cookiesに保存されたセッションに有効期限を設けたい場合（１ヶ月）
  def remember(user)
    user.remember
    # cookies の有効期限を 1ヶ月 にしたい場合
    cookies.encrypted[:user_id] = { value: user.id, expires: 1.month.from_now }
    cookies[:remember_token] = { value: user.remember_token, expires: 1.month.from_now }
  end

  def current_user
    if (user_id = session[:user_id])
      @current_user ||= User.find_by(id: user_id)
    elsif (user_id = cookies.encrypted[:user_id])
      user = User.find_by(id: user_id)
      if user && user.authenticated?(cookies[:remember_token])
        log_in user
        @current_user = user
      end
    end
  end

    # 永続的セッションを破棄する
    def forget(user)
      user.forget
      cookies.delete(:user_id)
      cookies.delete(:remember_token)
    end

    # ログアウトする（セッション情報を削除する）
    def log_out
      # ログアウト時に current_user の永続的セッションも破棄する
      forget(current_user)
      session.delete(:user_id)
      @current_user = nil
    end
end
