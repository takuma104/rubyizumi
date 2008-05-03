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