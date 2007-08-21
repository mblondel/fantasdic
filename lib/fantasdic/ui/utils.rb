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

class Gtk::TreeView
    def has_row_selected?
        self.selection.selected_each { return true }
        return false
    end
    
    def selected_iter
        self.selection.selected
    end

    def selected_iters
        array = []
        self.selection.selected_each do |model, path, iter|
            array << iter
        end
        array
    end
end


module Gtk::TreeModel
    def nb_rows
        count = 0
        self.each { count += 1 }
        count
    end
    alias :n_rows :nb_rows

    def empty?
        nb_rows == 0
    end    
end

class Gtk::ListStore
    def remove_last
        path = Gtk::TreePath.new((self.nb_rows - 1).to_s)
        last_iter = self.get_iter(path)
        self.remove(last_iter)
    end
end

class Gtk::ActionGroup
    def [](x)
        get_action(x)
    end
end

class Pango::Layout
    def size_points
        self.size.collect { |v| v / Pango::SCALE }
    end

    def width_points
        self.size[0] / Pango::SCALE
    end

    def height_points
        self.size[1] / Pango::SCALE
    end

    def width_points=(width)
        self.width = width * Pango::SCALE
    end
end

class Pango::FontDescription
    def size_points
        self.size / Pango::SCALE
    end
end