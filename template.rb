=begin
Author URI: https://trinitytakei.io
Instructions: $ rails new appname -d postgresql -m https://raw.githubusercontent.com/trinitytakei/speedtrack/master/template.rb
=end
RAILS_REQUIREMENT = "~> 6.0.0.beta3".freeze

def apply_template!
  assert_minimum_rails_version
  assert_valid_options
  assert_postgresql
  add_template_repository_to_source_path

  replace_readme_rdoc_with_readme_md

  generate_gemfile

  stop_spring
  add_users
  add_friendly_id
  remove_app_css
  add_overmind
  add_postcssrc
  add_tailwind
  setup_rspec
  setup_letter_opener_web

  copy_templates

  add_null_object_for_user

  rails_command "db:create"
  rails_command "db:migrate"

  git :init
  git add: "."
  git commit: %Q{ -m "Initial commit" }

  run_rspec
end

def assert_minimum_rails_version
  requirement = Gem::Requirement.new(RAILS_REQUIREMENT)
  rails_version = Gem::Version.new(Rails::VERSION::STRING)
  return if requirement.satisfied_by?(rails_version)

  prompt = "This template requires Rails #{RAILS_REQUIREMENT}. "\
           "You are using #{rails_version}. Please update rails!"
end

def assert_valid_options
  valid_options = {
    skip_gemfile: false,
    skip_bundle: false,
    skip_git: false,
    skip_test_unit: true
  }
  valid_options.each do |key, expected|
    next unless options.key?(key)
    actual = options[key]
    unless actual == expected
      fail Rails::Generators::Error, "You must set #{key} to #{expected}, currently it's #{actual}"
    end
  end
end

def assert_postgresql
  return if IO.read("Gemfile") =~ /^\s*gem ['"]pg['"]/
  fail Rails::Generators::Error,
       "This template requires PostgreSQL, "\
       "but the pg gem isn’t present in your Gemfile."
end

def replace_readme_rdoc_with_readme_md
  template "README.md.tt", force: true
  remove_file "README.rdoc"
end

def generate_gemfile
  template "Gemfile.tt", force: true
end

def gemfile_requirement(name)
  @original_gemfile ||= IO.read("Gemfile")
  req = @original_gemfile[/gem\s+['"]#{name}['"]\s*(,[><~= \t\d\.\w'"]*)?.*$/, 1]
  req && req.gsub("'", %(")).strip.sub(/^,\s*"/, ', "')
end

def add_template_repository_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    require "tmpdir"
    source_paths.unshift(tempdir = Dir.mktmpdir("tmp-rails-template-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      "--quiet",
      "https://github.com/trinitytakei/speeedtrack.git",
      tempdir
    ].map(&:shellescape).join(" ")

    if (branch = __FILE__[%r{speedtrack/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def stop_spring
  run "spring stop"
end

def add_users
  # Install Devise
  generate "devise:install"

  # Configure Devise
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'

  route "root to: 'home#index'"

  # Create Devise User
  generate :devise, "User", "username", "admin:boolean"

  # set admin boolean to false by default
  in_root do
    migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
    gsub_file migration, /:admin/, ":admin, default: false"
  end
end

def add_null_object_for_user
  user_extra_content = <<-CONTENT
    def is_a_guest?
      false
    end

    def is_not_a_guest?
      true
    end
  CONTENT

  inject_into_file "app/models/user.rb", user_extra_content, :before => /^end/
end

def add_friendly_id
  generate "friendly_id"

  insert_into_file(
    Dir["db/migrate/**/*friendly_id_slugs.rb"].first,
    "[5.2]",
    after: "ActiveRecord::Migration"
  )
end

def remove_app_css
  run "rm app/assets/stylesheets/application.css"
end

def add_overmind
  copy_file "Procfile"
end

def add_postcssrc
  copy_file ".postcssrc.yml"
end

def copy_templates
  directory "app", force: true
  directory "spec", force: true
end

def add_tailwind
  run "yarn --ignore-engines add postcss-cssnext tailwindcss"
  run "mkdir app/javascript/stylesheets"
  run "./node_modules/.bin/tailwind init app/javascript/stylesheets/tailwind.js"
  append_to_file "app/javascript/packs/application.js", 'import "stylesheets/application"'
  run "mkdir app/javascript/stylesheets/components"
  run "rm -r app/javascript/css"
end

def remove_unneeded_javascript
  gsub_file "app/javascript/packs/application.js", %r{require("@rails/ujs").start()\n}, ""
  gsub_file "app/javascript/packs/application.js", %r{require("channels")\n}, ""
end

def setup_rspec
  install_rspec

  pimp_rails_helper_rb
  pimp_spec_helper_rb
  pimp_dot_rspec
end

def install_rspec
  generate "rspec:install"
end

def pimp_rails_helper_rb
  gsub_file "spec/rails_helper.rb", /#[^\n]+?\n\s*config.fixture_path[^\n]+?\n\n/m, ''
  gsub_file "spec/rails_helper.rb", 'config.use_transactional_fixtures = true', 'config.use_transactional_fixtures = false'
  gsub_file "spec/rails_helper.rb", "# Dir[Rails.root.join('spec', 'support'", "Dir[Rails.root.join('spec', 'support'"

  extra_includes = <<-CONTENT

      config.include Devise::Test::IntegrationHelpers, type: :feature
      config.include Features, type: :feature

  CONTENT

  inject_into_file "spec/rails_helper.rb", extra_includes, :after => %r{RSpec.configure do \|config\|\n}

  shoulda_matcher_includes = <<-CONTENT
    Shoulda::Matchers.configure do |shoulda_config|
      shoulda_config.integrate do |with|
        with.test_framework :rspec
        with.library :rails
      end

      #TODO Remove this once thoughtbot fixes shoulda
      # see https://github.com/thoughtbot/shoulda-matchers/issues/1167
      #
      class ActiveModel::SecurePassword::InstanceMethodsOnActivation; end;
    end

  CONTENT

  #TODO: check how is this generated
  inject_into_file "spec/rails_helper.rb", extra_includes, :before => /^end/
end

def pimp_dot_rspec
  append_to_file ".rspec", '--color'
end

def pimp_spec_helper_rb
  gsub_file "spec/spec_helper.rb", "=begin", ""
  gsub_file "spec/spec_helper.rb", "=end", ""
end

def setup_letter_opener_web
  letter_opener_route = "  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?\n"
  inject_into_file "config/routes.rb", letter_opener_route, :after => /Rails.application.routes.draw do\n/

  environment "config.action_mailer.delivery_method = :letter_opener_web", env: 'development'
end

def run_rspec
  run "rspec"
end

apply_template!