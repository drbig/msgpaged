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

MsgSource = Struct.new(:name, :link)

class Message
  attr_reader :stamp, :source, :content
  attr_accessor :html

  def initialize(hash)
    @stamp = Time.parse(hash['stamp'])
    @source = MsgSource.new(hash['source']['name'], hash['source']['link'])
    @content = Sanitize.fragment(hash['content'], Sanitize::Config::BASIC)
    @html = nil
  end
end

class Cache < Array
  def initialize(max_size)
    @max_size = max_size
    @mutex = Mutex.new
  end

  def add(item)
    @mutex.synchronize do
      unshift(item)
      pop if length > @max_size
      item
    end
  end

  def get(n = 1)
    @mutex.synchronize do
      slice(0, n)
    end
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

  set :cache, Cache.new(32)

  register Sinatra::RocketIO
  io = Sinatra::RocketIO
  set :io, io

  helpers do
    def cache
      settings.cache
    end

    def io
      settings.io
    end

    def log(level, msg)
      request.logger.send(level, msg)
    end

    def crap(exception)
      log :error, exception.to_s
      log :error, exception.backtrace.join("\n")
    end
  end

  post '/msg/new' do
    content_type 'application/json'
    begin
      data = JSON.parse(request.env['rack.input'].read)
      Thread.new do
        new = 0
        data.each do |item|
          begin
            msg = Message.new(item)
            msg.html = haml :msg, locals: {msg: msg}
            cache.add(msg)
            new += 1
          rescue StandardError => e
            crap(e)
          end
        end
        io.push(:new, new) if new > 0
      end
      '{"success": true}'
    rescue StandardError => e
      crap(e)
      '{"success": false}'
    end
  end

  get '/msg/get/:n' do
    content_type 'application/json'
    cache.get(params[:n].to_i).map(&:html).reverse.to_json
  end

  get '/' do
    haml :front
  end
end

MSGPaged.run!
