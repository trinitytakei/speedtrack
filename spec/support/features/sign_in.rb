module Features
  def sign_in
    user = FactoryBot.create(:user)
    sign_in_as(user.email, user.password)
  end

  def sign_in_as(email, password)
    visit new_user_session_path
    fill_in "user_email", with: email
    fill_in "user_password", with: password
    click_on "Log in"
  end
end
