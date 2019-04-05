=begin
Author URI: https://trinitytakei.io
Instructions: $ rails new appname -d postgresql -m https://raw.githubusercontent.com/trinitytakei/speedtrack/master/template.rb
=end

def source_paths
  [File.expand_path(File.dirname(__FILE__))]
end

def add_gems
  gem 'devise'

  gem_group :development, :test do
    gem 'awesome_print'
    gem 'better_errors'
  end
end