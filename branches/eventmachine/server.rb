#!/usr/bin/env ruby -KU
#
#    RubyIZUMI Ver.0.20
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
$: << "./lib/hmac" #!!!
$: << "./lib/rtmp" #!!!
$: << "./lib/mp4" #!!!
$: << "./lib/rtp" #!!!
$: << "./lib/eventmachine" #!!!

require 'socket'
require 'rtmp_session'
require 'rtmp_mp4stream'
require 'optparse'
require 'stream_pool'
require 'logger'
require 'utils'
require 'openssl'
require 'server_main'

module RTMP
  FmsVer = 'RubyIZUMI/0,2,0,0'
end

def usage
  puts "Usage: server.rb (options) document_root_directory or filename"
  puts "Options: -p listen port (default=1935)"
  puts "         -v verbose"
  puts "         -l logfile (default=STDERR)"
  puts "         -d (daemonize)"
  puts "         -rtp rtpmode"
  exit(-1)
end

def parse_argv
  options = {:p=>1935,:v=>false,:log=>nil,:d=>false,:rtp=>false}

  opt = OptionParser.new
  opt.on('-p VAL') {|v| options[:p] = v.to_i }
  opt.on('-l VAL') {|v| options[:l] = v }
  opt.on('-v') {|v| options[:v] = true }
  opt.on('-d') {|v| options[:d] = true }
  opt.on('-rtp') {|v| options[:rtp] = true }
  opt.parse!(ARGV)

  if ARGV.size != 1
    usage
  end

  path = IZUMI::Filename.new(File.expand_path(ARGV.shift))
  if path.type == :unknown
    usage
  end
  
  [path, options]
end

def daemon
  return yield if $DEBUG
  Process.fork do
    Process.setsid
    Dir.chdir "/"
    trap("SIGINT") do 
      IzumiLogger.info "Interrupted. Exit."
      exit! 0 
    end
    trap("SIGTERM") do 
      IzumiLogger.info "Terminated. Exit."
      exit! 0 
    end
    trap("SIGHUP") do 
      IzumiLogger.info "Got HUP. Exit."
      exit! 0 
    end
    File.open("/dev/null") do |f|
      STDIN.reopen f
      STDOUT.reopen f
      STDERR.reopen f
    end
    yield
  end
  exit! 0
end

def create_stream_pool(path, rtpmode)
  pool = nil
  if rtpmode
    pool = IZUMI::StreamPoolRTP.new(path)
    IzumiLogger.info "RTP Mode SDP:#{path.path}"
  else
    pool = IZUMI::StreamPool.new(path)
    case path.type
    when :directory
      IzumiLogger.info "Document Root:#{path.path}"
    when :file
      IzumiLogger.info "Target File:#{path.path}"
    end
  end
  pool
end

def run(port, path, rtpmode)
  pool = create_stream_pool(path, rtpmode)
  s = IZUMI::Server.new('0.0.0.0', port)
  s.run(pool)
end

if $0 == __FILE__
  path, options = parse_argv
  
  # setup logger 
  IzumiLogger = Logger.new(if options[:l] then options[:l] else STDERR end)
  IzumiLogger.level = if options[:v] then Logger::DEBUG else Logger::INFO end  
  
  if options[:d]
    puts "Warnning: Please specify log file in daemon mode." unless options[:l]
    daemon do
      run(options[:p], path, options[:rtp])
    end
  else
    run(options[:p], path, options[:rtp])
  end
end
