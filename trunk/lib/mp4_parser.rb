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

module IZUMI
  class MP4Parser
    ContainerAtom = ['minf','stbl','mdia','trak']
    HookedAtom = { 
      "stsd" => :parse_stsd,
      "stsz" => :parse_stsz, 
      "stsc" => :parse_stsc,
      "stco" => :parse_stco,
      "stts" => :parse_stts, 
      "mdhd" => :parse_mdhd,
      "stss" => :parse_stss,
    }

    def initialize(io)
      @indexes = []
      @track = nil

      @io = io
      moov = find_moov
      if moov
        parse_moov(StringIO.new(moov))
      end
    end

    def get_frames
      frames = []
      avc1 = get_avc1_track_index
      if avc1
        m = get_track_metadata(avc1) 
        timescale = m[:time_scale].to_f
        et = get_sample_offset_size(avc1)
        et.each do |e|
          frames << [:video, e[0], e[1], (e[2].to_f / timescale), e[3]]
        end
      end

      mp4a = get_mp4a_track_index
      if mp4a
        m = get_track_metadata(mp4a) 
        timescale = m[:time_scale].to_f
        et = get_sample_offset_size(mp4a)
        et.each do |e|
          frames << [:audio, e[0], e[1], (e[2].to_f / timescale), e[3]]
        end
      end

      #sort by timecode
      frames.sort do |a, b|
        a[3] <=> b[3]
      end
    end

    def get_avc1_track_index
      idx = 0
      @indexes.each do |t|
        return idx if t[:data_format] == "avc1"
        idx+=1
      end
      false
    end

    def get_mp4a_track_index
      idx = 0
      @indexes.each do |t|
        return idx if t[:data_format] == "mp4a"
        idx+=1
      end
      false
    end

    def get_track_metadata(track)
      t = @indexes[track]
      {
        :data_format=>t[:data_format],
        :time_scale=>t[:time_scale],
        :extra_data=>t[:extra_data]
      }
    end

  private

    def get_sample_offset_size(track)
      t = @indexes[track]
      ret = []

      stsc_index = 0
      current_offset = 0
      current_sample = 0
      i = 0
      dts = 0
      stts_sample = 0
      stts_index = 0
      stss_index = 0

      key_off = if t[:stss] != nil && t[:stss].length > 0 && t[:stss][0] == 1 then 1 else 0 end

      t[:stco].each do |chank_offset|
        current_offset = chank_offset
        if (stsc_index + 1 < t[:stsc].size && i + 1 == t[:stsc][stsc_index + 1][:first])
          stsc_index += 1
        end

        t[:stsc][stsc_index][:count].times do

          keyframe = if t[:stss].nil? || t[:stss].length == 0 || current_sample + key_off == t[:stss][stss_index] then true else false end

          if keyframe && t[:stss] != nil
            if stss_index + 1 < t[:stss].length
              stss_index += 1
            end
          end

          sample_size = if t[:stsz_sample_size] > 0 
            t[:stsz_sample_size]
          else
            t[:stsz][current_sample]
          end

  #        puts "offset:#{current_offset} size:#{sample_size}"
          ret << [current_offset, sample_size, dts, keyframe]

          current_offset += sample_size
          current_sample += 1
          dts += t[:stts][stts_index][:duration]
          stts_sample+=1
          if stts_index + 1 < t[:stts_entries] && t[:stts][stts_index][:count] == stts_sample
            stts_sample = 0
            stts_index += 1
          end
        end
        i += 1
      end
      ret
    end  

  private
    def parse_moov(io)
      loop do
        size = io.read(4) 
        break unless size
        size = size.unpack('N')[0]
        atom = io.read(4).downcase
  #      puts "size:#{size} atom:#{atom}"
        unless ContainerAtom.index(atom)
          if (HookedAtom.has_key?(atom))
            self.send(HookedAtom[atom], io.read(size-8))
          else
            io.seek(size - 8, IO::SEEK_CUR)
          end
        else
          if atom == 'trak'
            @track = if @track then @track + 1 else 0 end
            @indexes[@track] = {}
          end
        end
      end
    end

    def find_moov
      begin
        loop do
          s = read(4).unpack('N')[0]
          atom = read(4)
          if atom.downcase == 'moov'
            return read(s-8)
          end
          seek(s-8)
        end
      rescue
      end
      nil
    end

    def read(size)
      buf = @io.read(size)
      if buf.nil? || buf.size != size
        raise "Premature end of file"
      end
      buf
    end

    def seek(size)
      @io.seek(size, IO::SEEK_CUR)
    end
    
    
    def read_u32(data, offset)
      data[offset..offset+3].unpack('N1')[0]
    end

    def read_u8(data, offset)
      data[offset..offset+1].unpack('C1')[0]
    end

    def parse_mdhd(data)
      time_scale = read_u32(data, 12)
      @indexes[@track][:time_scale] = time_scale
    end

    def parse_stsz(data)
      sample_size = read_u32(data, 4)
      entries = read_u32(data, 8)

      stsz = []
      n = 12
      entries.times do
        stsz << read_u32(data,n)
        n += 4
      end

      @indexes[@track][:stsz] = stsz
      @indexes[@track][:stsz_sample_size] = sample_size
    end

    def parse_stsc(data)
      entries = read_u32(data, 4)
      stsc = []
      n = 8
      entries.times do
        first = read_u32(data, n)
        n += 4
        count = read_u32(data, n)
        n += 4
        id = read_u32(data, n)
        n += 4
        stsc << {:first=>first,:count=>count,:id=>id}
      end

      @indexes[@track][:stsc] = stsc
    end

    def parse_stco(data)
      entries = read_u32(data, 4)
      stco = []
      n = 8
      entries.times do
        stco << read_u32(data, n)
        n += 4
      end

      @indexes[@track][:stco] = stco
    end

    def parse_stsd(data)
      entries = read_u32(data, 4)
      n = 8
      entries.times do 
        size = read_u32(data, n); n+=4
        format = data[n..(n+3)]; n+=4

        @indexes[@track][:data_format] = format

        case format.downcase
        when 'avc1'
          n+=8
          n+=34+32+4
          if (size-1+8) - n > 0
            @indexes[@track][:extra_data] = data[n..(size-1+8)]
          end
        when 'mp4a'
          parse_mp4a(data[n .. -1])
        end
      end
    end

    def parse_stts(data)
      entries = read_u32(data, 4)

      stts = []
      n = 8
      entries.times do
        count = read_u32(data, n)
        n += 4
        duration = read_u32(data, n)
        n += 4
        stts << {:count=>count,:duration=>duration}
      end

      @indexes[@track][:stts] = stts
      @indexes[@track][:stts_entries] = entries
    end

    def parse_stss(data)
      entries = read_u32(data, 4)

      stss = []
      n = 8
      entries.times do
        stss << read_u32(data, n)
        n += 4
      end
      @indexes[@track][:stss] = stss
    end

    def mp4_read_descriptor(data, pos)
      tag = read_u8(data, pos)
      pos += 1
      len = 0
      4.times do
        c = read_u8(data, pos)
        pos += 1
        len = (len << 7) | (c & 0x7f)
        break if (c & 0x80) == 0
      end    
      [tag, len, pos]
    end

    MP4ESDescrTag = 3
    MP4DecConfigDescrTag = 4
    MP4DecSpecificDescrtag  = 5

    def parse_mp4a(data)    
      pos = 8 + 16 + 2 + 2 
      pos += 4 + 4 #size + 'esds'
      pos += 4 #version + flags

      tag, len, pos = mp4_read_descriptor(data, pos)
      if tag == MP4ESDescrTag
        pos += 2 + 1
      else
        pos += 2
      end

      tag, len, pos = mp4_read_descriptor(data, pos)
      if tag == MP4DecConfigDescrTag
        object_type_id = read_u8(data, pos)
        pos += 1 + 1 + 3 + 4 + 4
        tag, len, pos = mp4_read_descriptor(data, pos)
        if tag == MP4DecSpecificDescrtag
          extradata = data[pos .. pos+len]
          @indexes[@track][:extra_data] = extradata
        end
      end
    end
  end
end

if $0 == __FILE__
  require 'pp'
  pp IZUMI::MP4Parser.new(open(ARGV.shift)).get_frames
end
