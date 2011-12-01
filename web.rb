require "sinatra/base"
require "oauth2"
require "haml"

class QuickTest < Sinatra::Base

  use Rack::Session::Cookie

  configure do
    set :app_file,        __FILE__
    set :port,            ENV['PORT']
    set :raise_errors,    Proc.new { false }
    set :show_exceptions, false
    set :clients,         {"www"  => OAuth2::Client.new(ENV['SALESFORCE_KEY'],
                                                        ENV['SALESFORCE_SECRET'],
                                                        :site          => 'https://login.salesforce.com',
                                                        :authorize_url => '/services/oauth2/authorize',
                                                        :token_url     => '/services/oauth2/token'),
                           "test" => OAuth2::Client.new(ENV['SALESFORCE_TEST_KEY'],
                                                        ENV['SALESFORCE_TEST_SECRET'],
                                                        :site          => 'https://test.salesforce.com',
                                                        :authorize_url => '/services/oauth2/authorize',
                                                        :token_url     => '/services/oauth2/token')}
  end
  
  post '/authenticate' do
    puts "settings.clients: #{settings.clients}"
    puts "params[:options]['environment']: #{params[:options]['environment']}"
    redirect start_authorization_url(params[:options]['environment'])
  end

  get '/unauthenticate' do
    request.env['rack.session'] = {}
    redirect '/'
  end

  get '/auth/salesforce:environment' do |environment|
    begin
      redirect client(environment).auth_code.authorize_url(:redirect_uri => callback_url(environment))
    rescue OAuth2::Error
      #reformatting because Sinatra sees code property on OAuth2::Error and incorrectly assumes it should be an Integer
      raise "#{$!.code},#{$!.description}"
    end
  end

  get '/auth/salesforce-:environment/callback' do |environment|
    begin
      access_token = client(environment).auth_code.get_token(params[:code], :redirect_uri => callback_url(environment))
      access_token.options[:mode] = :query
      access_token.options[:param_name] = :oauth_token
      raw_info ||= access_token.post(access_token['id']).parsed
      puts raw_info
      session[:salesforce] = {:id             => access_token.params['id'],
                              :issued_at      => access_token.params['issued_at'],
                              :refresh_token  => access_token.refresh_token,
                              :instance_url   => access_token.params['instance_url'],
                              :signature      => access_token.params['signature'],
                              :access_token   => access_token.token,
                              :user_id        => raw_info['user_id'],
                              :organization_id=> raw_info['organization_id'],
                              :thumbnail      => raw_info['photos']['thumbnail'],
                              :username       => raw_info['username']}
      puts session[:salesforce]
    rescue OAuth2::Error
      raise "#{$!.code},#{$!.description}"
    end
    redirect '/'
  end
  
  get '/*' do
    if session.has_key?(:salesforce)
      haml :authenticated 
    else
      haml :unauthenticated
    end
  end

  error do
    haml :error
  end

  # environment should be www or test
  # this method ensures that
  def sanitize_environment(environment = nil)
    environment.strip!    unless environment == nil
    environment.downcase! unless environment == nil
    environment = "www" if environment != "www" and environment != "test"
    environment
  end

  def start_authorization_url(environment = nil)
    x = "/auth/salesforce#{sanitize_environment(environment)}"
    puts "x = #{x}"
    x
  end

  def callback_url(environment = nil)
    environment = sanitize_environment(environment)
    "#{ENV['ORIGIN']}/auth/salesforce/callback"
  end

  def client(environment = nil)
    client = settings.clients[sanitize_environment(environment)]
    raise "No client!" unless client
    client
  end

  run! if app_file == $0

end