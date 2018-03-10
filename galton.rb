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
  require 'rack-ssl-enforcer'
  use Rack::SslEnforcer
end


get "/" do
  erb :'form'
end

post '/save' do
  redirect "/" unless params[:file]
  redirect "/" unless params[:file][:tempfile]

  upload = params[:file][:tempfile]
  @file = Tempfile.new('galton')
  @file.binmode
  @file << upload.read

  begin
    metadata = Yomu.new(@file.path).metadata

    # print out as a list
    @out = "<li>Tempfile: #{@file.path} (deleted)</li>";
    metadata.each do |k,v|
      next if k =~ /X-Parsed-By/
      @out << "<li>#{h k}: #{h v}</li>"
    end

  rescue Errno::EPIPE => e
    # Grab the java version in case we need to display it
    java_version = `java -version`

    @errors = "Broken pipe, try restarting the server?\n"
    @errors << "Details: #{e}\n"
    @errors << "Java version: #{java_version}"
  rescue JSON::ParserError => e
    # Grab the java version in case we need to display it
    java_version = `java -version`

    @errors = "Error: invalid metadata\n"
    @errors << "Details: #{e}\n"
    @errors << "Java version: #{java_version}"

  end

  @file.close
  @file.unlink

  erb :'show'
end
