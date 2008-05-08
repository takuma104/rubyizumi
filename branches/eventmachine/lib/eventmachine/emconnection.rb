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

module IZUMI
  class EMConnection < EventMachine::Connection
    def initialize(arg)
      @proc = arg
    end

    def post_init
      @io = FiberIO.new(self) {|io| @proc.call(io)}
    end

    def receive_data(data)
      @io.push(data)
    end

=begin
    def start_timer
      @ev_timer = EventMachine::PeriodicTimer.new(1) do
        yield
      end
    end

    def stop_timer
      @ev_timer.cancel
    end
=end

    # FIXME!
#    def unbind
#      raise ConnectionClosedException, 'Connection closed.'
#    end
  end
end