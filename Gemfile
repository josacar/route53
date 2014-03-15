source "https://rubygems.org"

gem 'emeril', :group => :release

group :integration do
  gem "test-kitchen"
  gem "kitchen-vagrant"
  gem "kitchen-docker"
end

group :test do
  gem "chefspec"
  gem "fog", :git => 'https://github.com/fog/fog.git'
end

group :test, :integration do
  gem "librarian-chef"
end