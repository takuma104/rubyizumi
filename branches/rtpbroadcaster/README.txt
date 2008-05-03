This is RubyIZUMI, an implementation of RTMP(H.264/MP4) server for Flash streaming.

== How to use:

$ ruby server.rb document_root_directory 

or 

$ ruby server.rb filename.mp4

- Specify H.264/AAC mp4 files. 
  You can also use H.264 video only mp4 files or AAC audio only mp4 files.
- Currently, RubyIZUMI does *not* support FLV files.

== To play streaming video on your browser:

$ cd player
$ rascut Player.as -s

- rascut: http://hotchpotch.rubyforge.org/
- Currently, it can play on Flash Player version 9,0,115,0 and 9,0,124,0 (I comfirmed).

Takuma Mori <takuma104@gmail.com>
