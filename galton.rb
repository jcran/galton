require 'sinatra'
require 'tempfile'
require 'yomu'

helpers do
  def h(text)
    Rack::Utils.escape_html(text)
  end
end

get "/" do
  erb :'form'
end

post '/save' do

  @filename = Tempfile.new('foo').path
  file = params[:file][:tempfile]

  File.open("#{@filename}", 'wb') do |f|
    f.write(file.read)
  end


  # Grab the java version in case we need to display it
  java_version = `java --version`

  begin
    metadata = Yomu.new(@filename).metadata

    # print out as a list
    @out = "";
    metadata.each{|k,v| @out << "<li>#{h k}: #{h v}</li>" }

  rescue Errno::EPIPE => e
    @errors = "Broken pipe, try restarting the server?\n"
    @errors << "Details: #{e}\n"
    @errors << "Java version: #{java_version}"
  rescue JSON::ParserError => e

    @errors = "Error: invalid metadata\n"
    @errors << "Details: #{e}\n"
    @errors << "Java version: #{java_version}"
  end

  erb :'show'
end
