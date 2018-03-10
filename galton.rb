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

$pid = 9999999
Thread.new do
  $pid = Yomu.server(:metadata, 9999)
end

# Trap ^C
Signal.trap("INT") {
  puts "Caught ^c, killing yomu"
  Yomu.kill_server!
  exit
}

# Trap `Kill `
Signal.trap("TERM") {
  puts "Caught kill, killing yomu"
  Yomu.kill_server!
  exit
}


get "/" do
  erb :'form'
end

post '/save' do
  # make sure our input is sane
  redirect "/" unless params[:file]
  redirect "/" unless params[:file][:tempfile]

  # check our captcha before doing anything in production
  redirect "/" if (settings.environment == :production && !verify_recaptcha)

  # otherwise proceed
  upload = params[:file][:tempfile]

  begin

    file = Tempfile.new('galton')
    file.binmode
    file << upload.read
    metadata = Yomu.new(file.path).metadata

    # print out as a list
    @out = "<li>Tempfile: #{file.path} (deleted)</li>";
    metadata.each do |k,v|
      next if k =~ /X-Parsed-By/
      @out << "<li>#{h k}: #{h v}</li>"
    end

  rescue Errno::EPIPE => e
    # Grab the java version in case we need to display it
    java_version = `java -version 2>&1`

    @errors = "Unable to contact Java\n"
    @errors << "Details: #{e}\n"
    @errors << "Java version: #{java_version}"
  rescue JSON::ParserError => e
    # Grab the java version in case we need to display it
    java_version = `java -version 2>&1`

    @errors = "Error: invalid metadata\n"
    @errors << "Details: #{e}\n"
    @errors << "Java version: #{java_version}"

  end

  # clean up
  file.close
  file.unlink

  erb :'show'
end
