require "rubygems"
require "sinatra"
require "linkedin"
require "erubis"
require "pdfkit"
require "./models"
require "./helpers"
#require "ruby-debug/debugger"

# Profile fields to request for the authenticated user's own profile
# when merging with connections.
own_fields = %w(id first-name last-name headline picture-url)

# All profile fields referenced when creating a resume.
resume_fields = %w(first-name last-name headline twitter-accounts
                   member-url-resources site-public-profile-request
                   summary specialties skills positions educations
                   honors recommendations-received)

# Set templating to escape HTML.
set :erubis, :escape_html => true
# Set sessions to expire after two weeks.
use Rack::Session::Cookie, :expire_after => 60 * 24 * 14
# Load the LinkedIn API credentials.
api_key = ApiKey.first

# PDFKit configuration. Use the bundled binary in production (Heroku).
PDFKit.configure do |config|
  wkhtmltopdf_path = File.join(File.dirname(__FILE__), "bin/wkhtmltopdf-amd64")
  config.wkhtmltopdf = wkhtmltopdf_path if ENV["RACK_ENV"] == "production"
  config.default_options = {:page_size => "A4"}
end

# Create the LinkedIn client and profile objects for all routes when
# authenticated.
before do
  @tagline = "LinkedOut lets you export LinkedIn profiles as clean PDF resumes."
  @client = LinkedIn::Client.new(api_key.token, api_key.secret)
  unless session[:auth].nil?
    @client.authorize_from_access *session[:auth]
    @profile = @client.profile :fields => own_fields
  end
end

# If authenticated, show the resume creation form,
# otherwise show the login page.
get "/" do
  if session[:auth].nil?
    erubis :index
  else
    # Add the authenticated user's own profiles to the list of
    # connections.
    @profiles = (@client.connections.all + [@profile]).sort_by {|p|
      p.first_name.upcase
    }
    erubis :create
  end
end

# Create a resume.
post "/" do
  @resume = Resume.first_or_create(:by => @profile.id, :for => params[:id])
  @resume.update(:email => params[:email])
  @profile = @client.profile :id => params[:id], :fields => resume_fields
  attachment @profile.first_name + @profile.last_name + ".pdf"
  PDFKit.new(erubis :resume, :layout => false).to_pdf
end

# Handles OAuth post and callback.
get "/login" do
  if params[:oauth_verifier].nil?
    args = {:oauth_callback => "#{request.url}"}
    request_token = @client.request_token args
    session[:request] = request_token.token, request_token.secret
    redirect @client.request_token.authorize_url
  else
    token, secret = session[:request]
    pin = params[:oauth_verifier]
    session[:auth] = @client.authorize_from_request token, secret, pin
    redirect "/"
  end
end

# Remove auth info from session to logout.
get "/logout" do
  session.delete :auth
  redirect "/"
end
