This is RubyIZUMI, an implementation of RTMP(H.264/MP4) server for Flash streaming.

== How to use:

$ ruby server.rb mp4_filename.mp4

- You must use H.264/AAC mp4 files. 
- Currently, RubyIZUMI does *not* support FLV files.

== To play streaming video on your browser:

$ cd player
$ rascut Player.as -s

- rascut: https://rubyforge.org/projects/hotchpotch/
- Currently, it can play on Flash Player version 9,0,115,0.

Takuma Mori <takuma104@gmail.com>

