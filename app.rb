
require "rubygems"
require "sinatra"
require "linkedin"
require "erubis"
require "pdfkit"
require "./models"
require "./helpers"
#require "ruby-debug/debugger"


own_fields = %w(id first-name last-name headline picture-url)

resume_fields = %w(first-name last-name headline twitter-accounts
                    member-url-resources site-public-profile-request
                    summary specialties skills positions educations
                    honors recommendations-received)

set :erubis, :escape_html => true
enable :sessions
api_key = ApiKey.first

PDFKit.configure do |config|
  wkhtmltopdf_path = File.join(File.dirname(__FILE__), "bin/wkhtmltopdf-amd64")
  config.wkhtmltopdf = wkhtmltopdf_path if ENV["RACK_ENV"] == "production"
  config.default_options = {:page_size => "A4"}
end

before do
  @client = LinkedIn::Client.new(api_key.token, api_key.secret)
  unless session[:auth].nil?
    @client.authorize_from_access *session[:auth]
    @profile = @client.profile :fields => own_fields
  end
end

get "/" do
  if session[:auth].nil?
    erubis :index
  else
    @profiles = (@client.connections.all + [@profile]).sort_by {|p|
      p.first_name.upcase
    }
    erubis :create
  end
end

post "/" do
  @resume = Resume.first_or_create(:by => @profile.id, :for => params[:id])
  @resume.update(:email => params[:email])
  @profile = @client.profile :id => params[:id], :fields => resume_fields
  attachment @profile.first_name + @profile.last_name + ".pdf"
  PDFKit.new(erubis :resume).to_pdf
end

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
