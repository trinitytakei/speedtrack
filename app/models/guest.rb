class Guest
  def is_a_guest?
    true
  end

  def is_not_a_guest?
    false
  end

  def user_signed_in?
    false
  end

  def username
    "Guest"
  end
end