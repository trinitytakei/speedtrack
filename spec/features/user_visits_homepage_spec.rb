# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'user visits homepage' do
  scenario 'as a guest' do
    visit root_path

    expect(page).to have_css 'h1', text: "Welcome, Guest!"
  end

  scenario 'as a logged in user' do
    sign_in

    expect(page).to have_css 'h1', text: "Welcome, FooBar!"
  end
end
