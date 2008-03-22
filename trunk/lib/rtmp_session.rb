#
#    RubyIZUMI
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

require 'rtmp_session_reader'
require 'rtmp_session_writer'
require 'rtmp_function_call'
require 'handshake_server'

module RTMP
  class Session
    HandshakeSize = 1536
    EnlargedChankSize = 4096
    
    def initialize(sock, stream)
      @sock = sock
      @stream = stream
      @reader = SessionReader.new(@sock)
      @writer = SessionWriter.new(@sock)
    end
    
    def do_session
      puts "> #{@sock.inspect} is accepted"
      
      handshake
      
      @writer.send_server_bandwidth
      @writer.send_client_bandwidth
      
      loop do
        begin
          pkt = @reader.get_packet
          case pkt.data_type
          when 20
      			pkt.extend FunctionCallExtension
            func = pkt.parsed_data.method.to_s
            puts "> func:#{func}"
            case func
            when 'connect'
              on_connect
            when 'createStream'
              on_createStream
            when 'play'
              on_play
            end
          else
            puts "> #{pkt.inspect}"
          end
        rescue => e
          puts "exception: #{e}"
          break
        end
      end
    end

private
    def handshake
     @sock.read(1)
     c_handcheck = @sock.read(HandshakeSize)
     @sock.write( "\3" << HandshakeServer << c_handcheck )
    	@sock.read(HandshakeSize)
     puts "<> handshaked"
    end
    
    def on_connect
      @writer.send_connect_result
    end
    
    def on_createStream
      @writer.send_create_stream_result
    end
    
    def on_play
      @reader.set_chank_size(EnlargedChankSize)
      @writer.send_set_chank_size_packet(EnlargedChankSize)
      @writer.send_command_AAA
      @writer.send_command_BBB
      @writer.send_play_start
      
      start_send_stream
    end    

    def start_send_stream
     Thread.new do
       offset = 3
       next_stop_time = offset
       start_time = Time.now.to_f
       @stream.each do |time, pkt|
         if time > next_stop_time
           sleep 1
           next_stop_time = Time.now.to_f - start_time + offset
           puts "< time:%.3f" % [next_stop_time]
         end
         @sock.write(pkt)
       end
     end
    end

  end
end





    