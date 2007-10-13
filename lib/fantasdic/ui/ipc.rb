# Fantasdic
# Copyright (C) 2006 - 2007 Mathieu Blondel
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# This file contains IPC mechanism using three possible backends:
# - Named pipes. This uses win32/pipe from the win32-utils package. This
#   approach is preferred on win32.
# - DRb (Distributed Ruby). This approach is portable but its main disadvantage
#   is that it may be blocked by the local firewall.
# - X11. This works by creating an invisible window, setting a uniquely named
#   atom on the root window which refers to the invisible window (so other
#   instances can find the window) and watching for property change events
#   on the invisible window. This approach is preferred on Unix.
#
# IPC is used in Fantasdic to make the application a single-instance
# application. It is possible to pass parameters to the running instance.

if Fantasdic::WIN32

begin
require "win32/pipe"
require "base64"
include Win32  

module Fantasdic
module UI
module IPC

    class Instance

        REMOTE = Fantasdic::TITLE

        def self.send(pclient, uri, value)
            pclient.write(Base64.encode64(Marshal.dump(value)))
            pclient.close
        end

        def self.find(uri)
            begin
                pclient = Pipe.new_client(uri)
                pclient
                #data = pclient.read # read data from server
            rescue PipeError
                nil
            end
        end    

        def initialize(uri, &block)
            Thread.new do
                pserver = Pipe.new_server(uri, Pipe::NOWAIT)
                pserver.connect
                while true
                    ok = pserver.read
                    if ok
                        params = Marshal.load(Base64.decode64(pserver.buffer))
                        block.call(params)
                        #pserver.write("") # send data to client
                        pserver.close
                        pserver.connect
                    end                    
                    sleep 0.5
                end                
            end # Thread
        end
    end

end
end
end

rescue LoadError # win32/pipe
  
# IPC mechanism using Ruby DRb (Distributed Ruby)
require "drb"

module Fantasdic
module UI
module IPC
    class Instance

        # The private ports range is between 49152 and 65535
        REMOTE = 'druby://127.0.0.1:56373'

        def self.send(block, uri, value)
            block.call(value)
        end

        def self.find(uri)
            begin
                DRb.start_service       
                block = DRbObject.new nil, uri
                block.to_proc
            rescue
                nil
            end
        end    

        def initialize(uri, &block)
            begin
                DRb.start_service uri, block
                Thread.new { DRb.thread.join }
            rescue
            end
        end

    end

end
end
end

end # rescue LoadError win32/pipe

else
# IPC mechanism using X11
# Code kindly provided by Geoff Youngs

module Gdk
    class Window
        STRING_ATOM = Gdk::Atom.intern('STRING')
        CARDINAL_ATOM = Gdk::Atom.intern('CARDINAL')

        def get_string(name)
            atom, value, size = Gdk::Property.get(self, name,
                                                  STRING_ATOM, false)
            value
        end

        def get_int(name)
            atom, value, size = Gdk::Property.get(self, name,
                                                  CARDINAL_ATOM, 0, 4, false)
            (value.is_a?(Array) and (value.size == 1)) ? value.first : value
        end

        def set_string(name,value)
            Gdk::Property.change(self, name, STRING_ATOM, 8,
                                 Gdk::Property::PropMode::REPLACE, value.to_s)
        end

        def del_string(name)
            Gdk::Property.delete( self, name )
        end
    end
end

module Fantasdic
module UI
module IPC

    class Instance < Gtk::Invisible

        MESSAGE_ARGS = "_RUBY_MARSHAL_DATA"
        REMOTE = 'FANTASDIC_IPC'

        def self.send(window, name, value)
            window.set_string(MESSAGE_ARGS, Marshal.dump(value))
            window.set_string(name, window.xid)
            Gdk::flush()
            Gtk.main_iteration while Gtk.events_pending?
        end

        def self.find(name)
            win_xid = Gdk::Window.default_root_window.get_string( name )
            return false if win_xid.nil?
            win = Gdk::Window.foreign_new(win_xid.to_i)
            return false unless win.kind_of?(Gdk::Window)
            return false unless win.get_string(name) == win_xid
            win
        end

        def initialize(atom_name,&block)
            @atom_name, @block = atom_name, block
            super()

            realize()
            window.set_string( atom_name, window.xid )
            Gdk::flush()
            add_events(Gdk::Event::PROPERTY_CHANGE_MASK)

            signal_connect("property-notify-event") do |widget,event|
                remote_event(event)
            end

            Gdk::Window.default_root_window.set_string(atom_name, window.xid)

            func = lambda do
                Gdk::Window.default_root_window.del_string(atom_name);
                false
            end
            ObjectSpace.define_finalizer(self, func)
       end

        def remote_event(event)
            name = event.atom.name
            if name == @atom_name
                data = window.get_string(MESSAGE_ARGS)
                if data and @block.kind_of?(Proc)
                    @block.call(Marshal.load(data))
                end
            end
            return (name == @atom_name) &&
                (window.get_string(name) != window.xid.to_s)
        end
    end

end
end
end

end # Fantasdic::WIN32

if $0 == __FILE__
    REMOTE='_RUBY_GTK_IPC_TEST'
    Gtk.init

    if ARGV.empty?
        ipc = IPC::Window.new(REMOTE) { |arg| p arg }
        p ipc.window
        Gtk.main
    else
        win = IPC.find(REMOTE)
        raise "No remote process" unless win
        p [win, win.xid, win.get_int('_NET_WM_PID'),
        win.get_string('WM_CLIENT_MACHINE'), ARGV]
        IPC.send(win, REMOTE, ARGV)
        Gtk.main_iteration while Gtk.events_pending?
    end
end
