#!/usr/bin/env ruby
# coding: utf-8

require 'httparty'
require 'json'
require 'optparse'

URL = 'http://:'
SOURCE = ''

config = {url: URL, source: SOURCE, label: nil, dry: false}
op = OptionParser.new do |o|
  o.banner = "Usage: #{$PROGRAM_NAME} [options] Message you want to send..."
  o.on('-u', '--url URL', "URL of msgpaged (default: #{URL})") {|a| config[:url] = a }
  o.on('-s', '--source SOURCE', "SOURCE identity (default: #{SOURCE})") {|a| config[:source] = a }
  o.on('-l', '--label TYPE,"TEXT"', Array, 'Add a label of type TYPE with TEXT') {|a| config[:label] = a }
  o.on('-d', '--[no-]dry-run', 'Do not actually send anything but dump JSON') {|a| config[:dry] = a }
end
op.parse!

if ARGV.length < 1
  STDERR.puts op
  STDERR.puts 'Remember to first edit the script and adjust URL and SOURCE.'
  exit(1)
end

data = {stamp: Time.now, source: {name: config[:source]},  content: ARGV.join(' ')}
if config[:label]
  type, text = config[:label]
  data[:label] = {type: type, text: text}
end

if config[:dry]
  puts data.to_json
  exit(0)
end

begin
  HTTParty.post(config[:url] + '/msg/new', body: data.to_json, headers: {'Content-Type' => 'application/json'})
rescue StandardError
  exit(2)
end
