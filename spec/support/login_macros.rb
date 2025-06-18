module LoginMacros
  def login_as(user)
    post login_path, params: { email: user.email, password: 'password' }
    follow_redirect! if response.redirect?
  end
end
