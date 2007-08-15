# Fantasdic
# Copyright (C) 2007 Mathieu Blondel
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

    class ComboBoxEntry < Gtk::ComboBoxEntry
        include GetText
        GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

        module Column
            STRING = 0
            SEARCH_HASH = 1
        end

        def initialize
            super
            @prefs = Preferences.instance

            self.model = Gtk::ListStore.new(String, Hash)
            self.clear

            renderer = Gtk::CellRendererText.new
            self.pack_start(renderer, true)

            self.set_cell_data_func(renderer) do |cel, renderer, model, iter|
                if iter[Column::SEARCH_HASH]
                    text = iter[Column::SEARCH_HASH][:word]
                    renderer.text = text
                end
            end

            renderer = Gtk::CellRendererText.new
            renderer.foreground = "grey"
            renderer.size_points = 8
            self.pack_start(renderer, false)

            self.set_cell_data_func(renderer) do |cel, renderer, model, iter|
                if iter[Column::SEARCH_HASH]
                    search = iter[Column::SEARCH_HASH]
                    text = search[:strategy] ? search[:strategy] : "define"
                    text += ", " + iter[Column::SEARCH_HASH][:dictionary]
                    renderer.text = text
                end
            end

            self.show_all
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
            search_iter[Column::STRING] = search[:word]
            search_iter[Column::SEARCH_HASH] = search
            search_iter
        end
        
        def append_search(search)
            search_iter = self.model.append()
            search_iter[Column::STRING] = search[:word]
            search_iter[Column::SEARCH_HASH] = search
            search_iter
        end
        
        def update(search)    
            # Append word to history
            search_iter = get_search_iter(search)
            
            search_iter = prepend_search(search) if search_iter.nil?
            
            # Delete a word if needed
            if self.model.nb_rows > @prefs.history_nb_rows
                self.model.remove_last
            end
        end
    end

end
end