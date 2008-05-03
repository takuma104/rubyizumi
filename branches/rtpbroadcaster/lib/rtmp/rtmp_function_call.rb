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

require 'amf_marshal'

module RTMP

	class FunctionCall
		def initialize (method,request_id,args,first_arg=nil)
			@method = method
			@request_id = request_id
			@args = args
			@first_arg = first_arg
		end
		def _amf_load (t_data)
			n_data = StringIO.new t_data
			@method,@request_id,@first_arg,*@args = AMF::Marshal.load_array(n_data)
		end
		def serialize
			return AMF::Marshal.dump_array([@method,@request_id,@first_arg]+@args)
		end
		def to_s
			t_str = "method : "<<@method.to_s<<"\n"
			t_str << "request_id : "<<@request_id.to_s<<"\n"
			t_str << "arguments : \n"<<@args.join("\n")<<"\n"
		end
		attr_writer :method,:request_id,:args,:first_arg
		attr_reader :method,:request_id,:args,:first_arg
	end
	
	module FunctionCallExtension
		def FunctionCallExtension.extend_object(obj)
			if obj.respond_to? :register_datatype
				super
				obj.register_datatype(20) do |t_data|
					n_func = FunctionCall.allocate
					n_func._amf_load t_data
					n_func
				end
			else
				raise "this object doesn't have the \"register_datatype\" method"
			end
		
		end
	end
end