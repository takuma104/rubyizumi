#!/usr/bin/env ruby -wKU
require 'socket'
require 'ipaddr'
#require '../debug/hexdump'
require 'base64'
require 'stringio'

module IZUMI
  class RtpReceiver
    def initialize(sdp, media)
      @mcast_addr = sdp[:addr]
      @mcast_port = sdp[:port]
      @media = media
      case media
      when :video
        profile = sdp[:fmtp][:profile]
        sps = sdp[:fmtp][:sps]
        pps = sdp[:fmtp][:pps]
        @extrabin = "\1" << profile << "\xFF\xE1"
        @extrabin << [sps.length].pack('n') << sps 
        @extrabin << "\1" << [pps.length].pack('n') << pps
      
#        @extrabin.hexdump
      when :audio
      end
    end
  
  private  
  
    def parse_rtp(pkt)
      {
        :sequence => pkt[2..3].unpack('n')[0],
        :timestamp => pkt[4..7].unpack('N')[0] / 90000.0,
        :payload_length => pkt.length - 12,
        :marker => pkt[1..2].unpack('C')[0] & 0x80 != 0
      }
    end

    def flush_reconbuf(dump, ctx)
      if ctx[:reconbuf]
        dump[:payload] << [ctx[:reconbuf].length].pack('N') << ctx[:reconbuf]
    #    puts "len:%d" % [ctx[:reconbuf].length]
        ctx[:reconbuf] = nil
      end
    end

    def parse_h264_rtp(pkt, ctx)
      dump = parse_rtp(pkt)
  
    #  pkt[0..24].hexdump

      buf = pkt[12..-1]
  
      nal = buf[0 .. 1].unpack('C')[0]
      type = nal & 0x1f
 
    #  puts "(nal & 0x80) = #{(nal & 0x80)}"
      raise "Fobidden zero bit: %02x" % [nal] unless (nal & 0x80) == 0
  
  
      dump[:payload] = ""
  
      if type == 0
        raise "Nal == 0"
      elsif type >= 1 && type <= 23
        flush_reconbuf(dump,ctx)
        len = buf.length
    #    puts "nal:%d len:%d" % [type, len]
        dump[:payload] << [len].pack('N') << buf
      elsif type == 24 #STAP-A
    #    buf.hexdump
        flush_reconbuf(dump,ctx)
        pos = 1
        remain = buf.length - pos
        while remain > 0
          len = buf[pos..pos+2].unpack('n')[0]
          pos += 2
          remain -= 2
          raise "Nal size error: remain=%d len=%d" % [remain, len] if remain < len
          dump[:payload] << [len].pack('N') << buf[pos..pos+len-1]
          type = buf[pos..pos+1].unpack('C')[0] #& 0x1f
          pos += len
          remain -= len
    #      puts "nal:0x%x len:%d" % [type, len]
        end
      elsif type == 28 #FU-A
        fu_header = buf[1..2].unpack('C')[0]
        start_bit = (fu_header >> 7) != 0
        reconstructed_nal = nal & 0xe0
        reconstructed_nal |= (fu_header & 0x1f)
    #    puts "reconstructed_nal:0x%x start_bit:%s" % [reconstructed_nal, start_bit.to_s]

    #=begin    
        if start_bit
          flush_reconbuf(dump,ctx)
          ctx[:reconbuf] = [reconstructed_nal].pack('C') << buf[2..-1]
        else
          if ctx[:reconbuf]
            ctx[:reconbuf] << buf[2..-1]
          else
            ctx[:reconbuf] = [reconstructed_nal].pack('C') << buf[2..-1]
          end
        end
    #=end
      else
        buf.hexdump
        raise "Unknow nal type:%d" % [type]
      end
  
      if dump[:marker]
        flush_reconbuf(dump,ctx)
      end
  
      dump
    end


    def write_to_file(buf)
      if @i == nil
        @i = 0
      else
        @i += 1
      end

      fw = open(sprintf('/tmp/r/%04d.bin',@i), 'wb')
      fw.write(buf)
      fw.close
    end
  
  public
    def each
      sock = UDPSocket.new

      sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEPORT, 1) #!!!
      sock.bind(Socket::INADDR_ANY, @mcast_port)

      ip =  IPAddr.new(@mcast_addr).hton + IPAddr.new("0.0.0.0").hton
      sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, ip)

      ctx = {:reconbuf=>nil}
      buf = ""
    
      first = true
      start_time = 0
      last_send_time = 0

      loop do
        msg, info = sock.recvfrom(65536)
    #    rtpinfo = parse_rtp(msg)
    
        rtpinfo = parse_h264_rtp(msg, ctx)
      
        if rtpinfo[:payload].length > 0
          buf << rtpinfo[:payload]
        end
      
        if rtpinfo[:marker]
          if first
  #          if (buf[4..5].unpack('C')[0] & 0x1f) == 5
              d = get_rtmp_packet_header(0,@extrabin.length,@media, true) << "\x17\0\0\0\0" << @extrabin
              yield(0,d)

              first = false
              start_time = rtpinfo[:timestamp]
              time = rtpinfo[:timestamp] - start_time
            
#              write_to_file(buf)
              es = get_payload_header(@media,true) << buf
              rtmp_packet = get_rtmp_packet_header(0, buf.length, @media, true) << get_rtmp_chanked_payload(es)
              yield(0,rtmp_packet)
            
  #          end
          else
            time = rtpinfo[:timestamp] - start_time
            keyframe = (buf[4..5].unpack('C')[0] & 0x1f) == 5
            t = ((time - last_send_time) * 1000.0).to_i
            last_send_time = time
            puts "t:#{t} keyframe:#{keyframe}"
            es = get_payload_header(@media,keyframe) << buf
#            write_to_file(buf)
            rtmp_packet = get_rtmp_packet_header(t, buf.length, @media, false) << get_rtmp_chanked_payload(es)
            yield(time,rtmp_packet)
          end

          buf = ""
        end
=begin  
        if rtpinfo[:payload].length > 8
          puts "%s %s time:%.3f seq:%d nal:%02x len:%d out:%d" % [prefix, 
              if rtpinfo[:marker] then "M" else "-" end,
              rtpinfo[:timestamp],
              rtpinfo[:sequence],
              rtpinfo[:payload][4..5].unpack('C')[0],
              rtpinfo[:payload_length],
              rtpinfo[:payload].length]
    #      rtpinfo[:payload][0..15].hexdump
        else
          puts "%s %s time:%.3f seq:%d nal:-- len:%d" % [prefix, 
              if rtpinfo[:marker] then "M" else "-" end,
              rtpinfo[:timestamp],
              rtpinfo[:sequence],
              rtpinfo[:payload_length]]
        end
=end
      end
    end
  
  private
    def get_u24buf(n)
      [n].pack("N")[1,3]
    end

    def get_rtmp_packet_header(time, size, type, first)
      if first
        str = "\x05"
      else
        str = "\x45"
      end
      str << get_u24buf(time)
      case type
      when :audio
        str << get_u24buf(size+2) << "\x08"
      when :video
        str << get_u24buf(size+5) << "\x09"
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
          ret << "\xc5"
        end
      end
      ret
    end
  end
end

if $0 == __FILE__
  require 'sdp_parser'
  include IZUMI
  
  i = 0
  fn = ARGV.shift
  raise "rtprepserver.rb sdpfilename" unless fn
  sdp = SdpParser.new(fn)
  raise "Not found video description in sdp." unless sdp.video
  r = RtpReceiver.new(sdp.video, :video)
  r.each do |time, pkt|
    puts "time:%.3f len:%d " % [time,pkt.length]
  end
end
