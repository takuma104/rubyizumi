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

require 'stringio'
require 'rtmp_function_call'

module RTMP
  class SessionWriter
    def initialize(sock)
      @chank_size = 128
      @chank_delimitor = 0xc3
      @sock = sock
    end
    
    def send_server_bandwidth
      @sock.write(serialize_packet(make_server_bandwidth))
    end
    
    def send_client_bandwidth
      @sock.write(serialize_packet(make_client_bandwidth))
    end
        
    def send_connect_result
      @sock.write(serialize_packet(make_connect_result_packet(1)))
    end

    def send_create_stream_result
      @sock.write(serialize_packet(make_create_stream_result_packet(2)))
    end
    
    def send_set_chank_size_packet(size)
      @sock.write(serialize_packet(make_set_chank_size_packet(size)))
    end
    
    def send_command_AAA
      @sock.write(serialize_packet(make_command_AAA_response))
    end
    
    def send_command_BBB
      @sock.write(serialize_packet(make_command_BBB_response))
    end
    
    def send_play_start
      @sock.write(serialize_packet(make_play_start_packet))
    end

  private

    def serialize_packet(pkt)
      pkt.size = pkt.data.length

      buf = [pkt.frame].pack('C')
  		buf << get_packed_u24(pkt.timer)
  		buf << get_packed_u24(pkt.size)
  		buf << pkt.data_type
  		buf << [pkt.obj].pack("N")

      chank_size = @chank_size
      pos = chank_size
      len = pkt.size
      
      if len <= pos
        buf << pkt.data
      else
        rest = len - pos
        io = StringIO.new(pkt.data)
        buf << io.read(pos)
        while 0 < rest
          buf << [@chank_delimitor].pack("C")
          n = if rest > chank_size then chank_size else rest end
          buf << io.read(n)
          rest -= n
        end
      end

      buf
    end

  
  private

    def make_connect_result_packet(request_id)
      method_name = "_result"
      connection_status = 	{
      				"level"=>"status",
      				"code"=>"NetConnection.Connect.Success",
      				"description"=>"Connection succeeded.",
      			}
      arguments = [connection_status]

      fa = {"capabilities"=>31.0, "fmsVer"=>FmsVer}

      return_string = FunctionCall.new(method_name, request_id, arguments, fa).serialize

      frame = 3
      timer = 0
      data_type = 20
      obj = 0
      Packet.new(frame,timer,return_string,data_type,obj)
    end

    def make_create_stream_result_packet(request_id)
      method_name = "_result"

      arguments = [1.0] 

      return_string = FunctionCall.new(method_name, request_id, arguments, nil).serialize

      frame = 3
      timer = 0
      data_type = 20
      obj = 0
      Packet.new(frame,timer,return_string,data_type,obj)
    end

    def make_set_chank_size_packet(size)
      frame = 2
      timer = 0
      data_type = 1
      obj = 0
      @chank_size = size
      Packet.new(frame,timer,[size].pack('N'),data_type,obj)
    end

    def make_play_start_packet(frame=5)
      method_name = "onStatus"
      request_id = 0

      arguments = [{"code"=>"NetStream.Play.Start", 
        "level"=>"status", 
        "description"=>"-", }
      ] 

      return_string = FunctionCall.new(method_name, request_id, arguments, nil).serialize

      timer = 0
      data_type = 20
      obj = 0x01000000
      Packet.new(frame,timer,return_string,data_type,obj)
    end

    def make_server_bandwidth
      frame = 2
      timer = 0
      data_type = 5
      obj = 0
      d = [0x00,0x26,0x25,0xa0].pack('C*')
      Packet.new(frame,timer,d,data_type,obj)
    end

    def make_client_bandwidth
      frame = 2
      timer = 0
      data_type = 6
      obj = 0
      d = [0x00,0x26,0x25,0xa0,0x02].pack('C*')
      Packet.new(frame,timer,d,data_type,obj)
    end

    def make_command_AAA_response
      frame = 2
      timer = 0
      data_type = 4
      obj = 0
      d = [0,4,0,0,0,1].pack('C*')
      Packet.new(frame,timer,d,data_type,obj)
    end

    def make_command_BBB_response
      frame = 2
      timer = 0
      data_type = 4
      obj = 0
      d = [0,0,0,0,0,1].pack('C*')
      Packet.new(frame,timer,d,data_type,obj) 
    end  

  private
  
    def get_packed_u24(num)
    	return [num].pack("N")[1,3]
    end
  end
end