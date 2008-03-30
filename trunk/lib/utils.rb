module IZUMI

  class Filename
    def initialize(path)
      @path = path
      @type = :unknown
      case File.ftype(path)
      when 'directory'
        @type = :directory
      when 'file'
        @type = :file
      end
    end
    
    attr_reader :type, :path
    
  end
end
