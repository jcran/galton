require 'recaptcha'
require 'sinatra'
require 'tempfile'
require 'yomu'
require 'puma'

helpers do
  def h(text)
    Rack::Utils.escape_html(text)
  end
end

#redirect all traffic to https over ssl with Sinatra
configure :production do
#  require 'rack-ssl-enforcer'
#  use Rack::SslEnforcer
  include Recaptcha::ClientHelper
  include Recaptcha::Verify

  # these will only work on localhost ... make your own at https://www.google.com/recaptcha
  Recaptcha.configure do |config|
    config.site_key  = ENV["RECAPTCHA_SITE_KEY"] || '6Le7oRETAAAAAETt105rjswZ15EuVJiF7BxPROkY' # (local key)
    config.secret_key = ENV["RECAPTCHA_SECRET_KEY"] || '6Le7oRETAAAAAL5a8yOmEdmDi3b2pH7mq5iH1bYK' # (local key)
  end
end

# Grab the java version in case we need to display it
$java_version=`java -version 2>&1`

# run the server in the background
$pid = Yomu.server(:metadata)

# Trap ^C
Signal.trap("INT") {
  puts "Caught ^c, killing yomu"
  Yomu.kill_server!
  `kill -9 #{$pid}`
  exit
}

# Trap `Kill `
Signal.trap("TERM") {
  puts "Caught kill, killing yomu"
  Yomu.kill_server!
  `kill -9 #{$pid}`
  exit
}

set :public_folder, "public"

get "/" do
  erb :'form'
end

post '/metadata' do

  # specify input
  if params[:file] && params[:file][:tempfile]
    user_input = :file
  elsif params[:uri]
    user_input = :uri
  else
    user_input = nil
  end

  # make sure our input is sane
  redirect "/" unless user_input

  # check our captcha before doing anything in production
  redirect "/" if (settings.environment == :production && !verify_recaptcha)


  begin

    if user_input == :file

      # read the file and parse
      upload = params[:file][:tempfile]
      file = Tempfile.new('galton')
      file.binmode
      file << upload.read
      metadata = Yomu.new(file.path).metadata

      # Clean up
      file.close
      file.unlink

    elsif user_input == :uri
      # Yomu is smart enough to download the file
      metadata = Yomu.new(params[:uri]).metadata
    end

    # print out as a list
    @out = "";
    metadata.each do |k,v|
      next if k =~ /X-Parsed-By/
      @out << "<li>#{h k}: #{h v}</li>"
    end

  rescue Errno::ECONNRESET => e
    @errors = "Unable to contact Java\n"
    @errors << "Details: #{e}\n"
    @errors << "Java version: #{$java_version}"
  rescue Errno::EPIPE => e
    @errors = "Unable to contact Java\n"
    @errors << "Details: #{e}\n"
    @errors << "Java version: #{$java_version}"
  rescue JSON::ParserError => e
    @errors = "Error: invalid metadata\n"
    @errors << "Details: #{e}\n"
  end

  erb :'metadata'
end
