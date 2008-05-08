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

require 'rtmp_mp4stream'
require 'sdp_parser'
require 'rtpreceiver'

module IZUMI
  class StreamPool
    def initialize(path)
      @path = path
      @pool = {}
    end

    def get(fn)
      if @path.type == :directory
        # add fn to path as document_root 
        path = File.join(@path.path, fn)
      else
        # ignore fn and just load from path
        path = @path.path
      end
      if @pool.has_key?(path)
        @pool[path]
      else
        IzumiLogger.debug "Loading...: #{path}"
        s = RTMP::MP4Stream.new(path)
        @pool[path] = s
        s
      end
    end  
  end
  
  class StreamPoolRTP
    def initialize(fn)
      sdp = SdpParser.new(fn)
      raise "Not found video description in sdp." unless sdp.video
      @s = RtpReceiver.new(sdp.video, :video)
    end
    
    def get(fn)
      @s
    end
  end

end