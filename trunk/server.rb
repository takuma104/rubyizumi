#!/usr/bin/env ruby -wKU
#
#    RubyIZUMI Ver.0.01
#
#    Copyright (C) 2008 Takuma Mori, SGRA Corporation
#    <mori@sgra.co.jp> <http://www.sgra.co.jp/en/>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

$: << "./lib" #!!!

require 'socket'
require 'rtmp_session'
require 'rtmp_mp4stream'
require 'optparse'

module RTMP
  FmsVer = 'RubyIZUMI/0,0,0,1'
end

OPTS = {:p=>1935}

opt = OptionParser.new
opt.on('-p VAL') {|v| OPTS[:p] = v.to_i }
opt.parse!(ARGV)

if ARGV.size != 1
  puts "Usage: server.rb (-p port) file.mp4"
  exit(-1)
end

mp4fn = ARGV.shift

puts "Parseing...: #{mp4fn}"
mp4stream = RTMP::MP4Stream.new(mp4fn)

gs = TCPServer.open(OPTS[:p])
puts "Server started. Port: #{OPTS[:p]}"

loop do
  Thread.start(gs.accept) do |s|
    begin
      session = RTMP::Session.new(s, mp4stream)
      session.do_session
    rescue => e
      puts "exception caught: #{e}"
    end
  end
end

#s = gs.accept
#session = RTMP::Session.new(s, mp4)
#session.do_session
