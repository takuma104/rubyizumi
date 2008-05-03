# AMF4R - AMF parser and RPC engine for Ruby
# Copyright 2002-2003  Yannick Connan <yannick@dazzlebox.com>
#
#This library is free software; you can redistribute it and/or
#modify it under the terms of the GNU Lesser General Public
#License as published by the Free Software Foundation; either
#version 2.1 of the License, or (at your option) any later version.
#
#This library is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#Lesser General Public License for more details.
#
#You should have received a copy of the GNU Lesser General Public
#License along with this library; if not, write to the Free Software
#Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#/

require 'stringio'

module AMF
	require 'singleton'
	AmfArgs = Struct.new("AmfArgs",:file,:links,:link_count,:to_return)
	AmfCustomObject = Struct.new("AmfCustomObject",:class_name,:properties)
	class MarshalClass
	
		include Singleton
		
		AMF_NUMBER = 0
		AMF_BOOLEAN = 1
		AMF_STRING = 2
		AMF_HASH = 3
		AMF_NIL = 5
		AMF_UNDEF = 6
		AMF_LINK = 7
		AMF_ASSOC_ARRAY = 8
		AMF_END = 9
		AMF_ARRAY = 10
		AMF_DATE = 11
		AMF_LONG_STRING = 12
		AMF_UNDEF_OBJ = 13
		AMF_XML = 15
		AMF_CUSTOM = 16
		
		def self.set_time_dif
			t_time = Time.new()
			t_time.gmtime
			t_time_a = t_time.to_a
			t_time.localtime
			u_time = Time.local(t_time_a[5],t_time_a[4],t_time_a[3],t_time_a[2],t_time_a[1],t_time_a[0],t_time.usec);
			time_dif = ((t_time.to_f - u_time.to_f)/60).to_i
			return time_dif
		end
		
		TIME_DIF = set_time_dif()
		
		def initialize
			@class_dumper_name_registry = Hash.new
			@class_dumper_action_registry = {}
			@class_loader_registry = {}
			
		end
		
		def register_dumper(class_obj, class_name=nil, &action)
			if class_name.nil?
				class_name = class_obj.name
			end
			@class_dumper_name_registry[class_obj] = class_name
			@class_dumper_action_registry[class_obj] = action
		end
		
		def unregister_dumper(class_obj)
			@class_dumper_name_registry.delete class_obj
			@class_dumper_action_registry.delete class_obj
		end
		
		def register_loader(class_name,&action)
			@class_load_registry[class_name] = action
		end
		
		def unregister_loader(class_name)
			@class_load_registry.delete class_name
		end
		
		def get_args(arg)
			if arg == nil
				t_str = StringIO.new("")
				t_arg = AmfArgs.new(t_str,Hash.new,0,true)
			elsif arg.respond_to? :read
				t_arg = AmfArgs.new(arg,Hash.new,0,false)
			else
				t_str = StringIO.new(arg)
				t_arg = AmfArgs.new(t_str,Hash.new,0,true)
			end
			return t_arg
		end
		
		def dump(obj,t_out=nil)
			args = get_args(t_out)
			_dump(obj,args)
			if args.to_return
				args.file.pos = 0
				return args.file.read
			else
				return true
			end
		end

		def dump_array(obj,t_out=nil)
			args = get_args(t_out)
			obj.each do |item|
				_dump(item,args)
			end
			if args.to_return
				args.file.pos = 0
				return args.file.read
			else
				return true
			end
		end

		def load(t_inner)
			args = get_args(t_inner)
			args.links = Array.new
			return _load(args)
		end
		
		def load_array(t_inner)
			args = get_args(t_inner)
			args.links = Array.new
			arr = []
			until args.file.eof? do
				arr.push _load(args)
			end
			return arr
		end
		
		def write_long(obj,t_out=nil)
			args = get_args(t_out)
			_write_long(obj,args)
			if args.to_return
				args.file.pos = 0
				return args.file.read
			else
				return true
			end
		end
		
		def write_short(obj,t_out=nil)
			args = get_args(t_out)
			_write_short(obj,args)
			if args.to_return
				args.file.pos = 0
				return args.file.read
			else
				return true
			end
		end
		
		def read_long(t_inner)
			args = get_args(t_inner)
			return _read_long(args)
		end
		
		def read_short(t_inner)
			args = get_args(t_inner)
			return _read_short(args)
		end
		
		def write_string(obj,t_out=nil)
			args = get_args(t_out)
			_write_string(obj,args)
			if args.to_return
				args.file.pos = 0
				return args.file.read
			else
				return true
			end
		end
		
		def read_string(t_inner)
			args = get_args(t_inner)
			return _read_string(args)
		end
		
		def write_long_string(obj,t_out=nil)
			args = get_args(t_out)
			_write_long_string(obj,args)
			if args.to_return
				args.file.pos = 0
				return args.file.read
			else
				return true
			end
		end
		
		def read_long_string(t_inner)
			args = get_args(t_inner)
			return _read_long_string(args)
		end
		
		def read_byte(t_inner)
			args = get_args(t_inner)
			return _read_byte(args)
		end
		
		def write_byte(obj,t_out=nil)
			args = get_args(t_out)
			_write_byte(obj,args)
			if args.to_return
				args.file.pos = 0
				return args.file.read
			else
				return true
			end
		end
		
		private
		
		def setLink(obj,args)
			if args.links.has_key? obj.object_id then
				args.file.write(AMF_LINK)
				_write_short(args.links[obj.id],args)
				return false
			else
				args.links[obj.object_id] = args.link_count
				args.link_count += 1
				return true
			end
		end
		def _write_byte(obj,args)
			args.file.write([obj].pack("c"))
		end

		def _write_short(obj,args)
			args.file.write([obj.to_i].pack("n"))
		end
		def _write_long(obj,args)
			args.file.write([obj.to_i].pack("N"))
		end
		def _write_string(obj,args)
			_write_short(obj.length,args)
			args.file.write(obj)
		end
		def _write_long_string(obj,args)
			_write_long(obj.length,args)
			args.file.write(obj)
		end
		
		def _dump(obj,args)
			case obj
			when String
				if obj.length < 65535 then
					_write_byte(AMF_STRING,args)
					_write_string(obj,args)
				else
					_write_byte(AMF_LONG_STRING,args)
					_write_long_string(obj,args)	
				end
			when Numeric
				_write_byte(AMF_NUMBER,args)
				args.file.write([obj.to_f].pack("G"))
			when Array
				if setLink(obj,args) then
					_write_byte(AMF_ARRAY,args)
					_write_long(obj.length,args)
					obj.each { |arr_obj|
						_dump(arr_obj,args)
					}
				end
			when Hash
				if setLink(obj,args) then
					_write_byte(AMF_HASH,args)
					obj.each { |h_key,h_val|
						_write_string(h_key.to_s,args)
						_dump(h_val,args)
					}
					_write_byte(0,args)
					_write_byte(0,args)
					_write_byte(AMF_END,args)
				end
			when Time
				_write_byte(AMF_DATE,args)
				args.file.write([obj.to_f * 1000].pack("G"))
				if TIME_DIF <= 0
					_write_short(-TIME_DIF,args)
				else
					_write_short(65535-TIME_DIF+1,args)
				end
			when TrueClass
				_write_byte(AMF_BOOLEAN,args)
				_write_byte(1,args)
			when FalseClass
				_write_byte(AMF_BOOLEAN,args)
				_write_byte(0,args)
			when NilClass
				_write_byte(AMF_NIL,args)
			else
				_write_obj(obj,args)
			end
		end
		
		def _write_obj(obj,args)
			if @class_dumper_action_registry.has_key? obj.class
				if setLink(obj,args) then
					_write_byte(AMF_CUSTOM,args)
					_write_string(@class_dumper_name_registry[obj.class],args)
					n_obj = @class_dumper_name_registry[obj.class].call(obj)
					n_obj.each { |h_key,h_val|
						_write_string(h_key.to_s,args)
						_dump(h_val,args)
					}
					_write_byte(0,args)
					_write_byte(0,args)
					_write_byte(AMF_END,args)
				end
			else
				
			end
		end
		
		def _read_byte(args)
			return args.file.read(1).unpack('c')[0]
		end
		
		def _read_short(args)
			return args.file.read(2).unpack('n')[0]
		end
		
		def _read_long(args)
			return args.file.read(4).unpack('N')[0]
		end
		
		def _read_string(args)
			return args.file.read(_read_short(args))
		end
		
		def _read_long_string(args)
			return args.file.read(_read_long(args))
		end
		
		def register(obj,args)
			args.links.push(obj)
		end
		
		def _load(args)
			vv = _read_byte(args)
			case vv
			when AMF_NUMBER
				return args.file.read(8).unpack('G')[0]
			when AMF_BOOLEAN
				t_b = _read_byte(args)
				if t_b == 0 then
					return false
				else
					return true
				end
			when AMF_STRING
				return _read_string(args)
			when AMF_HASH
				t_hash = Hash.new
				register(t_hash,args)
				loop do
					h_key = _read_string(args)
					h_val = _load(args)
					if h_val == :end_obj then
						break
					else
						t_hash[h_key] = h_val
					end
				end
				return t_hash
			when AMF_NIL
				return nil
			when AMF_UNDEF
				return nil
			when AMF_LINK
				return args.links[_read_short(args)]
			when AMF_ASSOC_ARRAY
				t_hash = Hash.new
				register(t_hash,args)
				le = _read_long(args)
				loop do
					h_key = _read_string(args)
					h_val = _load(args)
					if h_val == :end_obj then
						break
					else
						t_hash[h_key] = h_val
					end
				end
				return t_hash
			when AMF_END
				return :end_obj
			when AMF_ARRAY
				t_array = Array.new
				register(t_array,args)
				len = _read_long(args)
				len.times do
					t_array.push(_load(args))
				end
				return t_array
			when AMF_DATE
				get_time = args.file.read(8).unpack('G')[0]
				time_dif = _read_short(args)
				return Time.at(get_time/1000)
			when AMF_LONG_STRING
				return _read_long_string(args)
			when AMF_UNDEF_OBJ
				return nil
			when AMF_XML
				t_str = ""
				register(t_str,args)
				t_str << _read_long_string(args)
				return t_str
			when AMF_CUSTOM
				return _read_obj(args)
			else
				raise StandardError, "not understood: #{vv}"
			end
		end
		
		def _read_obj(args)
			class_name = _read_string(args)
			properties = Hash.new
			loop do
				h_key = _read_string(args)
				h_val = _load(args)
				if h_val == :end_obj then
					break
				else
					t_hash[h_key] = h_val
				end
			end
			
			t_obj = AmfCustomObject.new(class_name,properties)
			
			if @class_loader_registry.has_key? class_name
				n_obj = @class_loader_registry[class_name].call(t_obj)
			else
				n_obj = t_obj
			end
			
			register(n_obj,args)
			return n_obj
		end
	end
	Marshal = AMF::MarshalClass.instance

end