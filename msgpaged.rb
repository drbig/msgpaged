#!/usr/bin/env ruby
# coding: utf-8

require 'yaml'

require 'haml'
require 'json'
require 'sanitize'
require 'sinatra/base'
require 'sinatra/rocketio'

# fix Sinatra logging retardation
class String
  def join(*_); self; end
end

STDOUT.sync = STDERR.sync = true

if ARGV.length != 1
  STDERR.puts "Usage: #{$PROGRAM_NAME} config.yaml"
  exit(1)
end

begin
  $config = File.open(ARGV.first) {|f| YAML.load(f.read) }
rescue StandardError => e
  STDERR.puts 'Error loading config file'
  STDERR.puts e.to_s
  exit(2)
end

class Message
  attr_reader :stamp, :source, :content
  Source = Struct.new(:name, :link)

  def initialize(hash)
    @stamp = Time.parse(hash['stamp'])
    @source = Source.new(hash['source']['name'], hash['source']['link'])
    @content = Sanitize.fragment(hash['content'], Sanitize::Config::BASIC)
  end

  def to_s
    "#{@stamp.strftime('%H:%M:%S')} #{@source.name} #{@content}"
  end
end

class MSGPaged < Sinatra::Base
  configure do
    enable :static
    enable :logging
    enable :dump_errors
    enable :raise_errors

    set :bind, $config[:host]
    set :port, $config[:port]
    set :root, File.dirname(__FILE__)
    set :views, File.join(settings.root, 'views')
    set :public_dir, File.join(settings.root, 'public')
    set :haml, ugly: true
    set :cometio, timeout: 120, post_interval: 2, allow_crossdomain: true
    set :websocketio, port: $config[:io_port]
    set :rocketio, websocket: true, comet: true
  end

  register Sinatra::RocketIO
  io = Sinatra::RocketIO
  set :io, io

  io.on :connect do |client|
    puts "IO connected <#{client.session}> type:#{client.type} address:#{client.address}"
  end

  io.on :disconnect do |client|
    puts "IO disconnected <#{client.session}> type:#{client.type}"
  end

  helpers do
    def io
      settings.io
    end

    def crap(exception)
      puts exception.to_s
      puts exception.backtrace.join("\n")
    end
  end

  post '/msg/new' do
    content_type('application/json')
    begin
      data = JSON.parse(request.env['rack.input'].read)
      Thread.new do
        begin
          msg = Message.new(data)
          puts msg
          io.push(:msg, haml(:msg, locals: {msg: msg}))
        rescue StandardError => e
          crap(e)
        end
      end
      '{"success": true}'
    rescue StandardError => e
      crap(e)
      '{"success": false}'
    end
  end

  get '/' do
    haml(:front)
  end
end

MSGPaged.run!
