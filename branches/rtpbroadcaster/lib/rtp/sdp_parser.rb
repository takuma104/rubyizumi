#!/usr/bin/env ruby -wKU

require 'base64'

module IZUMI
  class SdpParser
    def initialize(sdp_fn)
      @video = nil
      @audio = nil

      io = open(sdp_fn)
      sdp = parse_sdp(io)
    
      sdp.each do |s|
        case s[:media]
          when 'video'
            @video = s
          when 'audio'
            @audio = s
        end
      end
    end
    
    attr_reader :video, :audio

  private
    def parse_media(str)
      m = str.match(/^(.*)\s(.*)\s(.*)\s(.*)$/)
      return {} unless m
      {
        :media => m[1],
        :port => m[2].to_i,
        :proto => m[3],
        :fmt => m[4].to_i
      }
    end

    def parse_connection(str)
      m = str.match(/^(.*)\s(.*)\s(.*)\/(\d+)$/)
      return {} unless m
      {
        :addr => m[3]
      }
    end

    def parse_attribute(str)
      m = str.match(/^(.*)\:(.*)$/)
      return {} unless m
      case m[1]
      when 'fmtp'
        {
          :fmtp => parse_attribute_fmtp(m[2])
        }
      when 'rtpmap'
        {
          :rtpmap => parse_attribute_rtpmap(m[2])
        }
      else
        {}
      end
    end

    def parse_hex_string_to_binstr(str)
      str.scan(/../).map {|e| e.hex }.pack('C*')
    end

    def parse_attribute_fmtp(str)
      m = str.match(/^\d+\s(.*)$/)
      return {} unless m
      m = m[1].scan(/[^;]*=[^;]*/)
      return {} unless m
  
      r = {}
      m.each do |e|
        if m = e.match(/^profile-level-id=(.*)$/)
          r[:profile] = parse_hex_string_to_binstr(m[1])
        elsif m = e.match(/^sprop-parameter-sets=(.*),(.*)$/)
          r[:sps] = Base64.decode64(m[1])
          r[:pps] = Base64.decode64(m[2])
        elsif m = e.match(/^config=(.*)$/)
          r[:config] = parse_hex_string_to_binstr(m[1])
        end
      end
      r
    end
  
    def parse_attribute_rtpmap(str)
      m = str.match(/^\d+\s(.*)$/)
      return {} unless m
      m = m[1].scan(/[^\/]+/)
      return {} unless m

      r = {
        :encoding_name => m[0],
        :clock_rate => m[1].to_i,      
      }
    
      r[:encoding_params] = m[2].to_i if m[2]
      r
    end

    def parse_sdp(io)
      media = nil
      ret = []

      io.readlines.each do |line|
        line.chomp!
        m = line.match(/^([a-z])=(.*)$/)
        if m
          case m[1]
          when 'm'
            m = parse_media(m[2])
            if m
              ret << media if media
              media = m
            end
          when 'c'
            if media
              media.update parse_connection(m[2])
            end
          when 'a'
            if media
              media.update parse_attribute(m[2])
            end
          end
        end
      end
      ret << media if media
      ret
    end
  end
end

if $0 == __FILE__
  require 'pp'
  require '../debug/hexdump.rb'

  sdp = IZUMI::SdpParser.new(ARGV.shift || "/tmp/untitled.sdp")

  puts "--- video"
  s = sdp.video
  if s
    pp s
    if s[:fmtp]
      s[:fmtp][:sps].hexdump if s[:fmtp][:sps]
      s[:fmtp][:pps].hexdump if s[:fmtp][:pps]
      s[:fmtp][:profile].hexdump if s[:fmtp][:profile]
    end
  end

  puts "--- audio"
  s = sdp.audio
  if s
    pp s
    if s[:fmtp]
      s[:fmtp][:config].hexdump if s[:fmtp][:config]
    end
  end

end
