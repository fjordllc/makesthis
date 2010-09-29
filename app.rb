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
require 'dm-serializer'
require 'dm-pager'
require 'exceptional'
require 'json'

class Profile
  include DataMapper::Resource

  property :id, Serial
  property :twitter, Slug, :required => true, :unique => true
  property :name, String
  property :description, String
  property :who_are_you, Text
  property :what_did_you_make, Text
  property :why_did_you_make, Text
  property :what_do_you_make_next, Text
  property :photo_url, Text, :format => :url
  property :icon_url, Text, :format => :url
  property :homepage_url, Text, :format => :url
  property :created_at, DateTime
  property :updated_at, DateTime
end

enable :static
set :haml, :attr_wrapper => '"', :ugly => false
set :sass, :style => :expanded
set :default_locale, 'ja'
set :api_per_page, 100
set :twitter_oauth_config, Proc.new {
  config = YAML.load(open('config.yml')) if ENV['RACK_ENV'] != 'production'
  {:key => ENV['TWITTER_OAUTH_KEY'] || config['twitter_oauth_key'],
   :secret => ENV['TWITTER_OAUTH_SECRET'] || config['twitter_oauth_secret'],
   :callback => ENV['TWITTER_OAUTH_CALLBACK_URL'] || config['twitter_oauth_callback_url'],
   :login_template => {:text => '<a href="/connect">Login using Twitter</a>'}}
}
use Rack::Exceptional, ENV['EXCEPTIONAL_API_KEY'] || 'key' if ENV['RACK_ENV'] == 'production'
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{File.expand_path(File.dirname(__FILE__))}/development.sqlite3")

before do
  subdomain = request.host.split('.').first
  unless %w(localhost makesthis-com makesthis).include?(subdomain)
    params[:twitter_name] = subdomain
  end

  session[:locale] = params[:locale] if params[:locale]
end

get '/' do
  if params[:twitter_name].blank?
    haml :index
  else
    @profile = Profile.first(:twitter => params[:twitter_name])
    haml :'profile/show'
  end
end

get '/api' do
  haml :api
end

get '/about' do
  haml :about
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
    redirect "http://#{user.info['screen_name']}.#{domain}/"
  else
    haml :'profile/edit'
  end
end

get '/profiles.js' do
  per_page = params[:per_page].blank? ? settings.api_per_page : params[:per_page].to_i
  per_page = per_page > settings.api_per_page ? settings.api_per_page : per_page

  sort = %w(id created_at updated_at).include?(params[:sort]) ? params[:sort] : 'id'
  order = %w(asc desc).include?(params[:order]) ? params[:order] : 'asc'

  profiles = Profile.all(:order => sort.to_sym.send(order)).
               page(params[:page], :per_page => per_page)
  content_type :json
  profiles.to_json
end

get '/profiles/:twitter.js' do |twitter|
  profile = Profile.first(:twitter => twitter)
  content_type :json
  profile.to_json
end

helpers do
  def logged_in?
    !user.nil? and user.client.authorized?
  end

  def root_url
    "http://#{domain}/"
  end

  def domain
    ENV['RACK_ENV'] == 'production' ? 'makesthis.com' : 'localhost:9393'
  end
end
