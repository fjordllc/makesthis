# encoding: utf-8

require 'sinatra'
require 'sinatra/r18n'
require 'padrino-helpers'
require 'oauth'
require 'oauth/consumer'
require 'grackle'
require 'haml'
require 'sass'
require 'dm-core'
require 'dm-migrations'
require 'dm-timestamps'
require 'dm-validations'
require 'dm-validations-i18n'
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

  validates_presence_of :twitter
  validates_presence_of :name
  validates_presence_of :description
  validates_presence_of :who_are_you
  validates_presence_of :what_did_you_make
  validates_presence_of :why_did_you_make
  validates_presence_of :what_do_you_make_next
  validates_presence_of :photo_url

  def domain
    self.twitter.gsub(/_/, '-')
  end
end

enable :sessions, :static
set :haml, :attr_wrapper => '"', :ugly => false
set :sass, :style => :expanded
set :default_locale, 'ja'
set :api_per_page, 100
use Rack::Exceptional, ENV['EXCEPTIONAL_API_KEY'] || 'key' if ENV['RACK_ENV'] == 'production'
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{File.expand_path(File.dirname(__FILE__))}/development.sqlite3")

before do
  session[:oauth] ||= {}

  if ENV['RACK_ENV'] == 'production'
    consumer_key = ENV['TWITTER_OAUTH_KEY']
    consumer_secret = ENV['TWITTER_OAUTH_SECRET']
  else
    config = YAML.load(open('config.yml'))
    consumer_key = config['twitter_oauth_key']
    consumer_secret = config['twitter_oauth_secret']
  end

  @consumer ||= OAuth::Consumer.new(consumer_key, consumer_secret, :site => "http://twitter.com")

  if !session[:oauth][:request_token].nil? && !session[:oauth][:request_token_secret].nil?
    @request_token = OAuth::RequestToken.new(@consumer, session[:oauth][:request_token], session[:oauth][:request_token_secret])
  end

  if !session[:oauth][:access_token].nil? && !session[:oauth][:access_token_secret].nil?
    @access_token = OAuth::AccessToken.new(@consumer, session[:oauth][:access_token], session[:oauth][:access_token_secret])
  end

  if @access_token
    @client = Grackle::Client.new(:auth => {
      :type => :oauth,
      :consumer_key => consumer_key,
      :consumer_secret => consumer_secret,
      :token => @access_token.token,
      :token_secret => @access_token.secret
    })

    @user = @client.account.verify_credentials? if !@user
  end

  # wildcard domain
  subdomain = request.host.split('.').first
  unless %w(localhost makesthis-com makesthis).include?(subdomain)
    params[:twitter_name] = subdomain
  end

  # locale
  session[:locale] = params[:locale] if params[:locale]
  DataMapper::Validations::I18n.localize! r18n.locale.code

  lang = YAML.load(open("i18n/#{r18n.locale.code}.yml"))
  DataMapper::Validations::I18n.translate_field_name_with(r18n.locale.code => lang['profile'])
end

get '/' do
  if params[:twitter_name].blank?
    haml :index
  else
    @profile = Profile.first(:twitter => params[:twitter_name])
    if @profile
      @meta_title = "#{@profile.domain.upcase} MAKES THIS"
      haml :'profile/show'
    else
      404
    end
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
  @profile = Profile.first_or_new(:twitter => @user.screen_name)
  haml :'profile/edit'
end

post '/profile' do
  login_required
  @profile = Profile.first_or_new(:twitter => @user.screen_name)
  @profile.attributes = params['profile']
  @profile.icon_url = @user.profile_image_url
  @profile.homepage_url = @user.url
  if @profile.save
    url = "http://#{twitter2domain(@user.screen_name)}.#{domain}/"
    if params[:tweet]
      status = "#{@profile.domain.upcase} MAKES THIS. #{url} #makesthis"
      @client.statuses.update! :status => status
    end
    redirect url 
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

get '/request' do
  @request_token = @consumer.get_request_token(:oauth_callback => "#{root_url}auth")
  session[:oauth][:request_token] = @request_token.token
  session[:oauth][:request_token_secret] = @request_token.secret
  redirect @request_token.authorize_url
end

get '/auth' do
  @access_token = @request_token.get_access_token :oauth_verifier => params[:oauth_verifier]
  session[:oauth][:access_token] = @access_token.token
  session[:oauth][:access_token_secret] = @access_token.secret
  redirect '/profile/edit'
end

get '/logout' do
  session[:oauth] = {}
  redirect '/'
end

not_found do
  haml :'404'
end

helpers do
  def logged_in?
    !!@access_token
  end

  def login_required
    redirect '/request' unless logged_in?
  end

  def twitter2domain(str)
    str.gsub(/_/, '-')
  end

  def root_url
    "http://#{domain}/"
  end

  def domain
    ENV['RACK_ENV'] == 'production' ? 'makesthis.com' : 'localhost:9393'
  end

  def strip_tags(text)
      text.gsub(/<.+?>/, '')
  end

  def truncate(text, options = {})
    options = {:length => 30, :ommision => '...'}.merge(options)
    if options[:length] < text.length
      text[0..options[:length]] + options[:ommision]
    else
      text
    end
  end
end
