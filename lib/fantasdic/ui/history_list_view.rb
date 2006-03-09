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

    class HistoryListView < Gtk::TreeView
        include GetText
        GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

        module Column
            SEARCH_HASH = 0
        end
        
        def initialize
            super()
            self.model = Gtk::ListStore.new(Hash)
            self.headers_visible = false
            self.rules_hint = true
            
            @prefs = Preferences.instance
            
            renderer = Gtk::CellRendererText.new
            col = Gtk::TreeViewColumn.new("Searched word", renderer)
            
            col.set_cell_data_func(renderer) do |col, renderer, model, iter|
                text = iter[Column::SEARCH_HASH][:word]
                text = text.utf8_slice(0..20) + "..." if text.utf8_length > 20
                renderer.text = text
            end
            append_column(col)
            
            # Resize the history when a row is deleted
            model.signal_connect("row-deleted") { self.columns_autosize }

            show_all
        end   
        
        def selected_search
            self.selected_iter[Column::SEARCH_HASH]
        end
        
        def get_search_iter(search)
            self.model.each do |model, path, iter|
                return iter if iter[Column::SEARCH_HASH] == search
            end    
            return nil
        end 
               
        def prepend_search(search)
            search_iter = self.model.prepend()
            search_iter[Column::SEARCH_HASH] = search
            search_iter
        end
        
        def append_search(search)
            search_iter = self.model.append()
            search_iter[Column::SEARCH_HASH] = search
            search_iter
        end
        
        def update(search)    
            # Append word to history
            search_iter = get_search_iter(search)
            
            search_iter = prepend_search(search) if search_iter.nil?
            
            # Select the word if it is not currently selected
            if selected_iter != search_iter
                self.selection.select_iter(search_iter)
            end
            
            # Delete a word if needed
            if self.model.nb_rows > @prefs.history_nb_rows
                self.model.remove_last
            end
            
            self.unselect_all
        end
    end

end
end
