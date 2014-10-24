source 'https://rubygems.org'
ruby '2.1.3'

gem 'i18n'
gem 'sinatra'
gem 'haml'
gem 'sass'
gem 'rake'
gem 'sinatra-r18n'
gem 'oauth'
gem 'grackle'
gem 'exceptional'
gem 'shotgun'
gem 'dm-migrations',  '1.0.2'
gem 'dm-timestamps',  '1.0.2'
gem 'dm-validations', '1.0.2'
gem 'dm-validations-i18n'
gem 'dm-types',       '1.0.2'
gem 'dm-serializer',  '1.0.2'
gem 'dm-pager'
gem 'padrino-helpers'

group :production do
  gem 'dm-postgres-adapter'
end

group :development do
  gem 'dm-sqlite-adapter'
end

group :test do
  gem 'shoulda'
  gem 'rack-test'
  gem 'dm-sqlite-adapter'
end
