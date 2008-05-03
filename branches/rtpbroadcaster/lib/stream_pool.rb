require 'rtmp_mp4stream'

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
end