# Fantasdic
# Copyright (C) 2006 Mathieu Blondel
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'libglade2'
require 'gtk2'

begin
    require 'gtktrayicon'
    require 'fantasdic/ui/ipc'
rescue LoadError
    $stderr.puts 'WARNING : Ruby/GtkTrayIcon was not found.'
end

require 'fantasdic/ui/glade_base'
require 'fantasdic/ui/utils'
require 'fantasdic/ui/alert_dialog'
require 'fantasdic/ui/about_dialog'
require 'fantasdic/ui/preferences_dialog'
require 'fantasdic/ui/add_dictionary_dialog'
require 'fantasdic/ui/history_list_view'
require 'fantasdic/ui/result_text_view'
require 'fantasdic/ui/main_app'

module Fantasdic
module UI
    
    def self.main
        Gtk.init

        # Start Fantasdic normally
        # Or ask the first process to pop up the window if it exists
        if defined? Gtk::TrayIcon
            win = IPC.find(IPC::REMOTE)
        else
            win = nil
        end

        if win
            IPC.send(win, IPC::REMOTE, "present")
            Gtk.main_iteration while Gtk.events_pending?
        else
            MainApp.new
            Gtk.main
        end
    end

    
end
end

