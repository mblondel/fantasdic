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

module Fantasdic
module UI

    class MatchesListView < Gtk::TreeView
        include GetText
        GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

        module Column
            MATCH = 0
        end
        
        def initialize
            super()
            self.model = Gtk::ListStore.new(String)
            self.headers_visible = false
            self.rules_hint = true
            
            @prefs = Preferences.instance
            
            renderer = Gtk::CellRendererText.new
            col = Gtk::TreeViewColumn.new("Match", renderer)

            col.set_cell_data_func(renderer) do |col, renderer, model, iter|
                text = iter[Column::MATCH]
                text = text.utf8_slice(0..15) + "..." if text.utf8_length > 15
                renderer.text = text
            end

            append_column(col)
            
            show_all
        end   
        
        def selected_match
            self.selected_iter[Column::MATCH]
        end
        
        def get_match_iter(match)
            self.model.each do |model, path, iter|
                return iter if iter[Column::MATCH] == match
            end    
            return nil
        end 
               
        def prepend_match(match)
            iter = self.model.prepend()
            iter[Column::MATCH] = match
            iter
        end
        
        def append_match(match)
            iter = self.model.append()
            iter[Column::MATCH] = match
            iter
        end

        def append_matches(matches)
            arr = []
            matches.each do |db, db_matches|
                arr += db_matches
            end
            arr.uniq!
            arr.sort!
            arr.each do |match|
                append_match(match)
            end
        end

        def select_first
            iter = self.model.iter_first
            self.selection.select_iter(iter)
        end

        def select_match(match)  
            # Append word to history
            iter = get_match_iter(match)
            
            # Select the word if it is not currently selected
            if iter and selected_iter != iter
                self.selection.select_iter(iter)
                scroll_to_cell(iter.path, nil, false, 0.0, 0.0)
            end            
        end
    end

end
end