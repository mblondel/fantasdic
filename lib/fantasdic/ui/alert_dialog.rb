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

module Fantasdic
module UI

    class MessageDialog < Gtk::MessageDialog
    
        def initialize(parent, message, type)
            super(parent, Gtk::Dialog::Flags::MODAL,
            type, Gtk::MessageDialog::BUTTONS_OK,
            message)
            
            self.signal_connect("response") { self.destroy }
            
            self.run
        end
    
    end

    class ErrorDialog < MessageDialog
    
        def initialize(parent, message = nil)
            super(parent, message, Gtk::MessageDialog::ERROR)
        end
        
    end
    
    class InfoDialog < MessageDialog
    
        def initialize(parent, message = nil)
            super(parent, message, Gtk::MessageDialog::INFO)
        end
        
    end

end
end
