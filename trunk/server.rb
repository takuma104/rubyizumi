#!/usr/bin/env ruby -wKU
#
#    RubyIZUMI Ver.0.13
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

require 'socket'
require 'rtmp_session'
require 'rtmp_mp4stream'
require 'optparse'
require 'stream_pool'
require 'logger'
require 'utils'

module RTMP
  FmsVer = 'RubyIZUMI/0,1,3,0'
end

def usage
  puts "Usage: server.rb (options) document_root_directory or filename"
  puts "Options: -p listen port (default=1935)"
  puts "         -v verbose (0:debug 1:info) (default=1)"
  puts "         -l logfile (default=STDERR)"
  puts "         -d (daemonize)"
  exit(-1)
end

def parse_argv
  options = {:p=>1935,:v=>1,:log=>nil,:d=>false}

  opt = OptionParser.new
  opt.on('-p VAL') {|v| options[:p] = v.to_i }
  opt.on('-v VAL') {|v| options[:v] = v.to_i }
  opt.on('-l VAL') {|v| options[:l] = v }
  opt.on('-d') {|v| options[:d] = true }
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

def server_loop(path, port)
  pool = IZUMI::StreamPool.new(path)

  case path.type
  when :directory
    IzumiLogger.info "Document Root:#{path.path}"
  when :file
    IzumiLogger.info "Target File:#{path.path}"
  end

  # disable DNS reverse lookup
  TCPSocket.do_not_reverse_lookup = true

  begin
    gs = TCPServer.open(port)
    IzumiLogger.info "Server started. Ver:#{RTMP::FmsVer} Pid:#{$$} Port:#{port}"
    loop do
      Thread.start(gs.accept) do |s|
        begin
          session = RTMP::Session.new(s, pool)
          session.do_session
        rescue => e
          puts "Exception caught: #{e}"
        ensure
          s.close
        end
      end
    end
  rescue Interrupt
  ensure
    gs.close
    IzumiLogger.info "Exit."
  end
end

if $0 == __FILE__
  path, options = parse_argv
  
  # setup logger 
  IzumiLogger = Logger.new(if options[:l] then options[:l] else STDERR end)
  IzumiLogger.level = if options[:v] == 1 then Logger::INFO else Logger::DEBUG end  
  
  if options[:d]
    puts "Warnning: Please specify log file in daemon mode." unless options[:l]
    daemon do
      server_loop(path, options[:p])
    end
  else
    server_loop(path, options[:p])
  end
end
