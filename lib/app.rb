require "sinatra"
require "oauth2"

set :root, File.dirname(__FILE__) + '/../'

use Rack::Session::Cookie

get '/' do
  <<-HTML
    <html><body>#{ENV['SALESFORCE_KEY']},#{ENV['SALESFORCE_SECRET']}</body></html>
    HTML
end

get '/auth/salesforce' do
  <<-HTML
    <html><body>/auth/salesforce</body></html>
    HTML
end

get '/auth/salesforce/callback' do
  <<-HTML
    <html><body>/auth/salesforce/callback</body></html>
    HTML
end

get '/logout' do
  <<-HTML
    <html><body>/logout</body></html>
    HTML
end

