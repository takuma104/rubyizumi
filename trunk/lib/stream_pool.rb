require 'rtmp_mp4stream'

module IZUMI
  class StreamPool
    def initialize(document_root)
      @document_root = document_root
      @pool = {}
    end

    def get(fn)
      path = File.join(@document_root, fn)
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