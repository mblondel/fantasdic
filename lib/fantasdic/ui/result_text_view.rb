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
    
    class LinkBuffer < Gtk::TextBuffer
        
        def initialize
            super
            create_tag("link", :foreground => "blue", 
                       :underline => Pango::AttrUnderline::SINGLE)
        end

        def has_selected_text?
            mstart, mend, selected = selection_bounds
            selected
        end

        def selected_text
            selection_mark = self.selection_bound          
            selection_iter = self.get_iter_at_mark(selection_mark)
            insert_mark = self.get_mark("insert")
            insert_iter = self.get_iter_at_mark(insert_mark)
            self.get_text(selection_iter, insert_iter)
        end

        def insert_link(iter, database, word)
            tag = create_tag(nil,
                              {
                                'foreground' => 'blue',
                                'underline' => Pango::AttrUnderline::SINGLE,
                              })
            tag.database = database
            tag.word = word

            insert(iter, word, tag)
        end
        
        def insert_with_links(db, text)
            non_links = text.split(/\{[\w\s\-]+\}/)
            links = text.scan(/\{[\w\s\-]+\}/)
            non_links.each_with_index do |sentence, idx|
                insert(@iter, sentence)
                insert_link(@iter, db, links[idx].slice(1..-2)) \
                    unless idx == non_links.length - 1
            end
        end

        def clear
            self.text = ""
            ["last-search-prev", "last-search-next"].each do |mark|
                delete_mark(mark) unless get_mark(mark).nil?
            end
            @iter = get_iter_at_offset(0)
            @definitions = nil
            @matches = nil
        end

        # Display methods
        def insert_header(txt)
            insert(@iter, txt, "header")
        end

        def insert_text(txt)
            insert(@iter, txt)
        end

        def insert_definitions(definitions)
            @definitions = definitions
            last_db = ""
            definitions.each_with_index do |d, i|
                if last_db != d.database
                    t_format = i == 0 ? "%s [%s]\n" : "\n%s [%s]\n"
                    insert_header(t_format %
                                       [d.description, d.database])
                    last_db = d.database
                else
                    insert_header("\n__________\n")
                end
                insert_with_links(d.database, d.body.strip)
            end
        end

        def insert_matches(matches)
            @matches = matches
            matches.each do |db, words|
                insert_header(db + "\n")
                insert_text(words.join(", "))
                # Print matches with links (but slow)    
                # i = 0
                # words.each do |w|
                #     @buf.insert_link(db, w)
                #     @buf.insert_text(", ") unless i == words.length
                #     i += 1
                # end
                insert_header("\n")
            end
        end
    end
    
    class ResultTextView < Gtk::TextView
        include GetText
        GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")
        
        type_register

        self.signal_new("link_clicked", 
                        GLib::Signal::ACTION,
                        nil,
                        GLib::Type["void"],
                        GLib::Type["VALUE"],
                        GLib::Type["VALUE"],
                        GLib::Type["VALUE"])
        
        def initialize
            super()
            self.buffer = LinkBuffer.new
            self.editable = false
            self.wrap_mode = Gtk::TextTag::WRAP_WORD
            self.cursor_visible = false
            self.left_margin = 3
            
            initialize_tags

            @hand_cursor = Gdk::Cursor.new(Gdk::Cursor::HAND2)
            @regular_cursor = Gdk::Cursor.new(Gdk::Cursor::XTERM)
            @hovering = false

            @press = nil
            signal_connect("button_press_event") do |w, event|
                @press = event.event_type
                false
            end

            signal_connect("button_release_event") do |w, event|
                if event.button == 1 and @press == Gdk::Event::BUTTON_PRESS \
                   and !self.buffer.has_selected_text?
                    win, x, y, modtype = window.pointer
                    if x and y
                        bx, by = window_to_buffer_coords(
                                  Gtk::TextView::WINDOW_TEXT, x, y)
                        if iter = get_iter_at_location(bx, by) 
                            follow_if_link(iter, event)
                        end
                    end
                end
                false
            end
            
            signal_connect("motion-notify-event") do |tv, event|
                x, y = tv.window_to_buffer_coords(Gtk::TextView::WINDOW_WIDGET, 
                                                  event.x, event.y)
                set_cursor_if_appropriate(x, y)
                self.window.pointer
                
                false    
            end
            
            signal_connect("visibility-notify-event") do |tv, event|
                window, wx, wy = tv.window.pointer
                bx, by = tv.window_to_buffer_coords(
                            Gtk::TextView::WINDOW_WIDGET, wx, wy)
                set_cursor_if_appropriate(bx, by)
                false    
            end

            show_all
        end

        def follow_if_link(iter, event)
            iter.tags.each do |t|
                if t.word
                    Gtk.idle_add do
                        signal_emit("link_clicked", t.database, t.word, event)
                    end
                    break
                end
            end
        end

        def set_cursor_if_appropriate(x, y)
            buffer = self.buffer
            iter = self.get_iter_at_location(x, y)

            hovering = false

            tags = iter.tags
            tags.each do |t|
                if t.word
                    hovering = true
                    break
                end
            end

            if hovering != @hovering
                @hovering = hovering

                window = self.get_window(Gtk::TextView::WINDOW_TEXT)

                window.cursor = if @hovering
                    @hand_cursor
                else
                    @regular_cursor
                end
            end
        end
        
        def initialize_tags
            self.buffer.create_tag("header", :pixels_above_lines => 15,
                                             :pixels_below_lines => 15,
                                             :size_points => 11,
                                             :foreground => '#005500')
        end

        def find_backward(str)
            return false if str.empty?

            last_search = self.buffer.get_mark("last-search-prev")

            start_iter, end_iter = self.buffer.bounds

            if last_search.nil?
                iter = end_iter
            else
                iter = self.buffer.get_iter_at_mark(last_search)
            end

            match_start, match_end = iter.backward_search(
                                       str, 
                                       Gtk::TextIter::SEARCH_TEXT_ONLY |
                                       Gtk::TextIter::SEARCH_VISIBLE_ONLY,
                                       nil)

            unless match_start.nil?
                scroll_to_iter(match_start, 0.0, true, 0.0, 0.0)
                self.buffer.place_cursor(match_end)
                self.buffer.move_mark(self.buffer.selection_bound, match_start)
                self.buffer.create_mark("last-search-prev", match_start, false)
                self.buffer.create_mark("last-search-next", match_end, false)
                return true
            end

            return false
        end

        def find_forward(str, is_typing=false)
            start_iter, end_iter = self.buffer.bounds

            if str.empty?
                self.buffer.place_cursor(start_iter)
                return false
            end

            if !is_typing
                last_search = self.buffer.get_mark("last-search-next")
            else
                last_search = self.buffer.get_mark("last-search-prev")
            end

            if last_search.nil? or str != @last_str
                iter = start_iter
                self.buffer.place_cursor(start_iter)
            else
                iter = self.buffer.get_iter_at_mark(last_search)
            end

            match_start, match_end = iter.forward_search(
                                       str, 
                                       Gtk::TextIter::SEARCH_TEXT_ONLY |
                                       Gtk::TextIter::SEARCH_VISIBLE_ONLY,
                                       nil)

            @last_str = str

            unless match_start.nil?
                scroll_to_iter(match_start, 0.0, true, 0.0, 0.0)
                self.buffer.place_cursor(match_end)
                self.buffer.move_mark(self.buffer.selection_bound, match_start)
                self.buffer.create_mark("last-search-prev", match_start, false)
                self.buffer.create_mark("last-search-next", match_end, false)
                return true
            else            
                return false
            end
        end
        
    end
end

end

module Gtk
    class TextTag
        attr_accessor :word, :database
    end
end
