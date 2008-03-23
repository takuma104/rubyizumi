#!/usr/bin/env ruby -wKU
#
#    RubyIZUMI Ver.0.02
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
require 'stream_pool'
require 'logger'

module RTMP
  FmsVer = 'RubyIZUMI/0,0,0,2'
end

def usage
  puts "Usage: server.rb (options) document_root_directory/"
  puts "Options: -p listen port (default=1935)"
  puts "         -v verbose (0:debug 1:info) (default=1)"
  puts "         -l logfile (default=STDERR)"
  exit(-1)
end

OPTS = {:p=>1935,:v=>1,:log=>nil}

opt = OptionParser.new
opt.on('-p VAL') {|v| OPTS[:p] = v.to_i }
opt.on('-v VAL') {|v| OPTS[:v] = v.to_i }
opt.on('-l VAL') {|v| OPTS[:l] = v }
opt.parse!(ARGV)

if ARGV.size != 1
  usage
end

document_root = File.expand_path(ARGV.shift)
if File.ftype(document_root) != "directory"
  usage
end

# setup logger 
IzumiLogger = Logger.new(if OPTS[:l] then OPTS[:l] else STDERR end)
IzumiLogger.level = if OPTS[:v] == 1 then Logger::INFO else Logger::DEBUG end

pool = IZUMI::StreamPool.new(document_root)

gs = TCPServer.open(OPTS[:p])
IzumiLogger.info "Document Root: #{document_root}"
IzumiLogger.info "Server started. Port: #{OPTS[:p]}"

loop do
  Thread.start(gs.accept) do |s|
    begin
      session = RTMP::Session.new(s, pool)
      session.do_session
    rescue => e
      puts "exception caught: #{e}"
    end
  end
end

#s = gs.accept
#session = RTMP::Session.new(s, mp4)
#session.do_session
