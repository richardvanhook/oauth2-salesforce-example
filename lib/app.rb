require "sinatra"
require "oauth2"
require "haml"

set :raise_errors, Proc.new { false }
set :show_exceptions, false
set :root, File.dirname(__FILE__) + '/../'
   
use Rack::Session::Cookie

post '/authenticate' do
  redirect '/auth/salesforce'
end

get '/unauthenticate' do
  request.env['rack.session'] = {}
  redirect '/'
end

get '/auth/salesforce' do
  begin
    redirect client.auth_code.authorize_url(:redirect_uri => redirect_uri)
  rescue OAuth2::Error
    #reformatting error because Sinatra sees code property on OAuth2::Error and things it should be an Integer
    raise "#{$!.code},#{$!.description}"
  end
end

get '/auth/salesforce/callback' do
  begin
    access_token = client.auth_code.get_token(params[:code], :redirect_uri => redirect_uri)
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
  puts session.class
  puts session.has_key?(:salesforce)
  if session.has_key?(:salesforce)
    haml :authenticated 
  else
    haml :unauthenticated
  end
end

error do
  haml :error
end  

def client
  client = OAuth2::Client.new(
    ENV['SALESFORCE_KEY'],
    ENV['SALESFORCE_SECRET'],
    :site          => 'https://login.salesforce.com',
    :authorize_url => '/services/oauth2/authorize',
    :token_url     => '/services/oauth2/token'
  )
end

def redirect_uri
  "#{ENV['ORIGIN']}/auth/salesforce/callback"
end