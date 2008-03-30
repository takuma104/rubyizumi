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

require 'stringio'
require 'mp4_parser'

module RTMP
  class MP4Stream
    def initialize(fn)
      @fn = fn
      info = IZUMI::MP4Parser.new(File.new(@fn))
      @frames = info.get_frames
      avc1=info.get_avc1_track_index
      if avc1
        @video_extra = info.get_track_metadata(avc1)[:extra_data][8..-1]
      end
      mp4a=info.get_mp4a_track_index
      if mp4a
        @audio_extra = info.get_track_metadata(mp4a)[:extra_data]
      end
    end
    
    attr_reader :fn
     
    def each
      mp4 = open(@fn, 'rb')

      a_cnt = 0
      v_cnt = 0

      loop_offset = 0

      loop do
        last_timecode = 0
        base = 0

        @frames.each do |e|
          t = ((e[3]-base)*1000.0)
          time = t.round
          size = e[2]

          first = false
          case e[0]
          when :audio
            first = if a_cnt == 0 then true else false end
          when :video
            first = if v_cnt == 0 then true else false end
          end

          mp4.seek(e[1])
          es = mp4.read(size)
          es = get_payload_header(e[0],e[4]) << es
          rtmp_packet = get_rtmp_packet_header(time, size, e[0], first) << get_rtmp_chanked_payload(es)

          if first
            case e[0]
            when :audio
              mp4ah = @audio_extra
              d = get_rtmp_packet_header(0,mp4ah.length,:audio,true) << "\xaf\0" << mp4ah
              yield(0, d)
            when :video
              avch = @video_extra
              d = get_rtmp_packet_header(0,avch.length,:video, true) << "\x17\0\0\0\0" << avch
              yield(0, d)
            end
          end

          yield(loop_offset + e[3], rtmp_packet)

          case e[0]
          when :audio
            a_cnt+=1
          when :video
            v_cnt+=1
          end
 
          last_timecode = e[3]

          base += t.round.to_f / 1000.0
        end

        loop_offset += last_timecode
      end

      mp4.close
    end
  
  private
    def get_u24(n)
      [n].pack("N")[1,3]
    end

    def get_rtmp_packet_header(time, size, type, first)
      if first
        str = "\x05"
      else
        str = "\x45"
      end
      str << get_u24(time)
      case type
      when :audio
        str << get_u24(size+2) << "\x08"
      when :video
        str << get_u24(size+5) << "\x09"
      end

      if first
        str << "\1\0\0\0"
      end
  
      str
    end

    def get_payload_header(type,keyframe)
      case type
      when :audio
        return "\xaf\x01"
      when :video
        if keyframe
          return "\x17\x01\0\0\0"
        else
          return "\x27\x01\0\0\0"
        end
      end
    end

    def min(a,b)
      if a > b then b else a end
    end

    def get_rtmp_chanked_payload(payload)
      len = payload.length
      s = StringIO.new(payload)
      ret = ""
      while len > 0
        r = min(len, 4096)
        ret << s.read(r)
        len -= r
        if len > 0
          ret << "\xc5" # chank marker
        end
      end
      ret
    end
  end
end

