This is RubyIZUMI, an implementation of RTMP(H.264/MP4) server for Flash streaming.

== How to use:

$ ruby server.rb document_root_directory

- You must use H.264/AAC mp4 files in document_root_directory.
- Currently, RubyIZUMI does *not* support FLV files.

== To play streaming video on your browser:

$ cd player
$ rascut Player.as -s

- rascut: http://hotchpotch.rubyforge.org/
- Currently, it can play on Flash Player version 9,0,115,0 (latest).

Takuma Mori <takuma104@gmail.com>

