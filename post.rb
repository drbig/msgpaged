#!/usr/bin/env ruby
# coding: utf-8

require 'json'
require 'httparty'

URL = 'http://:'
SOURCE = ''

if ARGV.length < 1
  STDERR.puts "Usage: #{$PROGRAM_NAME} Message you want to send..."
  STDERR.puts 'Remember to first edit the script and adjust URL and SOURCE.'
  exit(1)
end

begin
  HTTParty.post(URL + '/msg/new',
                body: {stamp: Time.now, source: {name: SOURCE},  content: ARGV.join(' ')}.to_json,
                headers: { 'Content-Type' => 'application/json' })
rescue StandardError
  exit(2)
end
