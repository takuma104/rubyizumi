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

require 'rtmp_packet'

module RTMP
  class SessionReader
    Frame = Struct.new("Frame",:timer,:size,:data_type,:obj)

    def initialize(f)
      @f = f
      @chank_size = 128
  		@frames_in = {}
    end
  
    def set_chank_size(size)
      @chank_size = size
    end
  
  	def get_packet
 			f_byte = read_bytes(1)
			first_number = f_byte.unpack("C")[0]

			packet_type = first_number >> 6
			frame_number = first_number & 0x3F
			
			if frame_number == 0
				frame_number = read_bytes(1).unpack("C")[0]
			elsif frame_number == 1
				frame_number = read_bytes(2).unpack("n")[0]
			end

			if ! @frames_in.has_key? frame_number
				@frames_in[frame_number] = Frame.new(0,0,0,0)
				if packet_type != 0
					raise StandardError, "packet error"
				end
			end
			
			case packet_type
			when 0
				@frames_in[frame_number].timer = getMediumInt()
				@frames_in[frame_number].size = getMediumInt()
				@frames_in[frame_number].data_type = read_bytes(1).unpack("C")[0]
				@frames_in[frame_number].obj = read_bytes(4).unpack("N")[0]
			when 1
				@frames_in[frame_number].timer = getMediumInt()
				@frames_in[frame_number].size = getMediumInt()
				@frames_in[frame_number].data_type = read_bytes(1).unpack("C")[0]
			when 2
				@frames_in[frame_number].timer = getMediumInt()
			end

      chank_size = @chank_size
      packet_str = ""
      pos = chank_size
      len = @frames_in[frame_number].size

      if len <= pos
        packet_str = read_bytes(len)
      else  
        rest = len - pos
        packet_str  << read_bytes(pos)  
        while 0  < rest
          read_bytes(1) #chank  
          n = if rest > chank_size then chank_size else rest end
          packet_str << read_bytes(n)
          rest -= n
        end
      end
      
      Packet.new(frame_number, 
        @frames_in[frame_number].timer,
        packet_str,
        @frames_in[frame_number].data_type,
        @frames_in[frame_number].obj)
    end
      
  private

		def getMediumInt
  		num_array = read_bytes(3).unpack("C*")
  		num = num_array[0]<< 16 ^ num_array[1]<< 8 ^ num_array[2]
  		return num
  	end
  	  	
  	def read_bytes(n)
      buf = @f.read(n)
      raise StandardError, 'Connection closed.' unless buf
      buf
	  end
	  
  end
end





    