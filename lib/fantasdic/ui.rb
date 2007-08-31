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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'libglade2'
require 'gtk2'

module Fantasdic
module UI

    SUPPORTS_STATUS_ICON = defined? Gtk::StatusIcon
    SUPPORTS_PRINT = defined? Gtk::PrintOperation and not WIN32

    def self.main
        options = CommandLineOptions.instance

        Gtk.init

        # Start Fantasdic normally
        # Or ask the first process to pop up the window if it exists
        instance = IPC::Instance.find(IPC::Instance::REMOTE)

        if ARGV.length == 2
            params = {:dictionary => ARGV[0], :strategy => options[:match],
                      :word => ARGV[1]}
        else
            params = {}
        end

        if instance
            IPC::Instance.send(instance, IPC::Instance::REMOTE, params)
        else             
            MainApp.new(params)
            Gtk.main
        end
    end

    
end
end

require 'fantasdic/ui/glade_base'
require 'fantasdic/ui/utils'
require 'fantasdic/ui/alert_dialog'
require 'fantasdic/ui/about_dialog'
require 'fantasdic/ui/preferences_dialog'
require 'fantasdic/ui/add_dictionary_dialog'
require 'fantasdic/ui/combobox_entry'
require 'fantasdic/ui/matches_listview.rb'
require 'fantasdic/ui/result_text_view'
require 'fantasdic/ui/print' if Fantasdic::UI::SUPPORTS_PRINT
require 'fantasdic/ui/ipc'
require 'fantasdic/ui/main_app'