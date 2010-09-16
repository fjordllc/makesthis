require 'sinatra'
require 'sinatra/r18n'
require 'sinatra-twitter-oauth'
require 'haml'
require 'sass'
require 'dm-core'
require 'dm-migrations'
require 'dm-timestamps'
require 'dm-validations'
require 'dm-types'
require 'exceptional'
require 'builder'

class Profile
  include DataMapper::Resource

  property :id, Serial
  property :twitter, Slug, :required => true, :unique => true
  property :name, String
  property :description, String
  property :who_are_you, Text
  property :who_are_you_ja, Text
  property :what_did_you_make, Text
  property :what_did_you_make_ja, Text
  property :why_did_you_make, Text
  property :why_did_you_make_ja, Text
  property :what_do_you_make_next, Text
  property :what_do_you_make_next_ja, Text
  property :photo_url, Text, :format => :url
  property :icon_url, Text, :format => :url
  property :homepage_url, Text, :format => :url
  property :created_at, DateTime
  property :updated_at, DateTime
end

#DataMapper.auto_migrate!

enable :sessions, :static
set :haml, :attr_wrapper => '"', :ugly => false
set :sass, :style => :expanded
set :default_locale, 'ja'
set :twitter_oauth_config,
      :key => 'Kx1N5EQ9nQ7SQlu9i7EYA',
      :secret => 'EgNg5Rh5EyaCqNILYVTrdYDDnSWhxr8Z51d8eal70GI',
      :callback => (ENV['TWITTER_OAUTH_CALLBACK_URL'] || 'http://localhost:9393/auth'),
      :login_template => {:text => '<a href="/connect">Login using Twitter</a>'}
use Rack::Exceptional, ENV['EXCEPTIONAL_API_KEY'] || 'key' if ENV['RACK_ENV'] == 'production'
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{File.expand_path(File.dirname(__FILE__))}/development.sqlite3")

before do
  subdomain = request.host.split('.').first
  puts "subdomain: #{subdomain}"
  unless %w(localhost makesthis-com makesthis).include?(subdomain)
    params[:twitter_name] = subdomain
  end
end

get '/' do
  if params[:twitter_name].blank?
    haml :index
  else
    @profile = Profile.first(:twitter => params[:twitter_name])
    haml :'profile/show'
  end
end

get '/profile/edit' do
  login_required
  @profile = Profile.first_or_new(:twitter => user.info['screen_name'])
  haml :'profile/edit'
end

post '/profile' do
  login_required
  @profile = Profile.first_or_new(:twitter => user.info['screen_name'])
  @profile.attributes = params['profile']
  @profile.icon_url = user.info['profile_image_url']
  @profile.homepage_url = user.info['url']
  if @profile.save
    if ENV['RACK_ENV'] == 'production'
      redirect "http://#{user.info['screen_name']}.makesthis.com/"
    else
      redirect "http://#{user.info['screen_name']}.localhost:9393/"
    end
  else
    haml :'profile/edit'
  end
end

helpers do
  def logged_in?
    !user.nil? and user.client.authorized?
  end
end
