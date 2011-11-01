
require "rubygems"
require "sinatra"
require "linkedin"
require "erubis"
require "pdfkit"
require "./models"
require "./helpers"
#require "ruby-debug/debugger"

profile_fields = %w(first-name last-name headline twitter-accounts
                    member-url-resources site-public-profile-request
                    summary specialties skills positions educations
                    honors recommendations-received)

set :erubis, :escape_html => true
enable :sessions
use PDFKit::Middleware
PDFKit.configure do |config|
  wkhtmltopdf_path = File.join(File.dirname(__FILE__), "bin/wkhtmltopdf-amd64")
  config.wkhtmltopdf = wkhtmltopdf_path if ENV["RACK_ENV"] == "production"
  config.default_options = {:page_size => "A4"}
end

api_key = ApiKey.first

before do
  @client = LinkedIn::Client.new(api_key.token, api_key.secret)
  unless session[:auth].nil?
    @client.authorize_from_access *session[:auth]
  end
end

get "/" do
  if session[:auth].nil?
    args = {:oauth_callback => "#{request.url}callback"}
    request_token = @client.request_token args
    session[:request] = request_token.token, request_token.secret
    redirect @client.request_token.authorize_url
  else
    redirect "/resume.pdf"
  end
end

get "/callback" do
  token, secret = session[:request]
  pin = params[:oauth_verifier]
  session[:auth] = @client.authorize_from_request token, secret, pin
  redirect "/resume"
end

get "/resume.pdf" do
  @profile = @client.profile :fields => profile_fields
  @profile.email = "steve@jupo.org"
  erubis :resume
end
