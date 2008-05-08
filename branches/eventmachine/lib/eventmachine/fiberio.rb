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

module IZUMI
  class FiberIO
    def initialize(connection)
      @recv_data = ''
      @connection = connection
      Generator.new do |g|
        @generator = g
        yield(self)
      end
    end
  
    def read(size)
      loop do
        d = pop(size)
        if d
          return d
        else
          remain = size - @recv_data.size
          @generator.yield(remain)
        end
      end
    end
  
    def write(buf)
      @connection.send_data buf
    end
  
    def push(data)
      @recv_data << data
      if @generator.next?
        @generator.next
      end
    end
  
    def close
      @connection.close_connection_after_writing
    end
  
    def peeraddr
      addr = Socket.unpack_sockaddr_in(@connection.get_peername)
      ["AF_INET", addr[0], addr[1], addr[1]]
    end

=begin    
    def start_timer(&block)
      @connection.start_timer(&block)
    end
    
    def stop_timer
      @connection.stop_timer
    end
=end
    
  private
    def pop(size)
      if @recv_data.size >= size
        r = @recv_data[0..size-1]
        @recv_data = @recv_data[size..-1]
        r
      else
        nil
      end
    end
  end
end