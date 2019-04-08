FactoryBot.define do
  factory :user do
    username { "FooBar" }
    email    { "foo@bar.com" }
    password { "s1kr1t" }
  end
end
