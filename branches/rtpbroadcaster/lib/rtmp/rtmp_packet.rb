############################################################################
#    Copyright (C) 2003/2004 by yannick connan                             #
#    yannick@dazzlebox.com                                                 #
#                                                                          #
#    This program is free software; you can redistribute it and#or modify  #
#    it under the terms of the GNU Library General Public License as       #
#    published by the Free Software Foundation; either version 2 of the    #
#    License, or (at your option) any later version.                       #
#                                                                          #
#    This program is distributed in the hope that it will be useful,       #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU Library General Public     #
#    License along with this program; if not, write to the                 #
#    Free Software Foundation, Inc.,                                       #
#    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
############################################################################

module RTMP

	RawData = Struct.new("RawData",:data_type,:data)

	class Packet
		def initialize (frame,timer,t_data,data_type,obj)
			@frame = frame
			@timer = timer
			@data_type = data_type
			@obj = obj
			@parsed = false
			@parsed_data = nil
			@size = t_data.length
			@data = t_data
			@types = {}
		end
		attr_writer :frame,:timer,:size,:obj
		attr_reader :frame,:timer,:size,:data_type,:obj,:data

		def data=(data)
			@parsed = false
			@data = data
		end
		
		def data_type=(data_type)
			@parsed = false
			@data_type = data_type
		end
		
		def register_datatype (data_type,&action)
			@types[data_type.to_i] = action
		end

		def parsed_data
			if ! @parsed
				if @types.has_key? @data_type
					@parsed_data = @types[@data_type].call(@data)
				else
					@parsed_data =  RawData.new(@data_type,@data)
				end
				@parsed = true
			end
			return @parsed_data
		end
		
		def length
      return @data.length if @data
      0
	  end
	end
end