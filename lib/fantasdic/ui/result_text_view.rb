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

    class CharacterZoomWindow < Gtk::Window

        DEFAULT_FONT = Pango::FontDescription.new("sans 150")
        DEFAULT_WIDTH = 300
        DEFAULT_HEIGHT = 300

        def initialize(parent, word)
            super()
            self.transient_for = parent            
            self.decorated = false

            p_width, p_height = parent.size

            x, y = parent.position

            x += (p_width - DEFAULT_WIDTH) / 2
            y += (p_height - DEFAULT_HEIGHT) / 2

            move(x, y)
    
            @word = word

            set_default_size(DEFAULT_WIDTH, DEFAULT_HEIGHT)

            @textview = Gtk::TextView.new
            @textview.buffer.create_tag("text",
                                        :font_desc => DEFAULT_FONT,
                                        :justification => Gtk::JUSTIFY_CENTER)
            @iter = @textview.buffer.get_iter_at_offset(0)
            @textview.buffer.insert(@iter, word, "text")
 
            @button = Gtk::Button.new(Gtk::Stock::CLOSE)
            @button.signal_connect("clicked") { self.destroy }

            vbox = Gtk::VBox.new

            vbox.pack_start(@button, false, false)

            scroll = Gtk::ScrolledWindow.new.add(@textview)        
            scroll.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
            vbox.pack_start(scroll)

            add(vbox)

            show_all            
        end

    end
    
    class LinkBuffer < Gtk::TextBuffer

        HEADER = 0
        TEXT = 1
        LINK = 2

        MAX_FONT_SIZE = 24
        MIN_FONT_SIZE = 8
        
        DEFAULT_HEADER_FONT_SIZE = 12
        DEFAULT_FONT_SIZE = 10
        RATIO = DEFAULT_HEADER_FONT_SIZE / DEFAULT_FONT_SIZE.to_f

        DEFAULT_FONT = Pango::FontDescription.new("Sans #{DEFAULT_FONT_SIZE}")

        DEFAULT_HEADER_FONT = DEFAULT_FONT.dup
        DEFAULT_HEADER_FONT.size_points = DEFAULT_HEADER_FONT_SIZE

        attr_accessor :scrolled_window, :definitions

        def initialize
            super
            initialize_tags
            self.clear
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

        def clear
            self.text = ""
            ["last-search-prev", "last-search-next"].each do |mark|
                delete_mark(mark) unless get_mark(mark).nil?
            end
            @entries = []
            @iter = get_iter_at_offset(0)            
            # Make the scroll go up
            #@scrolled_window.vadjustment.value = \
            #    @scrolled_window.vadjustment.lower            
        end

        # Display methods
        def insert_header(txt)
            @entries << [HEADER, txt]
            insert(@iter, txt, "header")
        end

        def insert_text(txt)
            @entries << [TEXT, txt]
            insert(@iter, txt, "text")
        end

        def insert_link(word)
            # Removes bad chars that may appear in links
            word = word.gsub(/(\n|\r)/, "").gsub(/(\s)+/, " ")
            @entries << [LINK, word]
            insert(@iter, word, "link")
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
                insert_with_links(d.body.strip)
            end
        end

        def insert_with_links(text)
            non_links = text.split(/\{[\w\s\-]+\}/)
            links = text.scan(/\{[\w\s\-]+\}/)
            non_links.each_with_index do |sentence, idx|
                insert_text(sentence)
                insert_link(links[idx].slice(1..-2)) \
                    unless idx == non_links.length - 1
            end
        end

        # Change text size

        def increase_size            
            text_tag = self.tag_table.lookup("text")
            text_size = text_tag.size_points
            unless text_size >= MAX_FONT_SIZE
                self.tag_table.each do |tag|
                    if tag.name == "header"
                        tag.size_points = header_font_size(text_size + 2)
                    else
                        tag.size_points += 2
                    end
                end
                redisplay
            end
        end

        def decrease_size            
            text_tag = self.tag_table.lookup("text")
            text_size = text_tag.size_points
            unless text_size <= MIN_FONT_SIZE
                self.tag_table.each do |tag|
                    if tag.name == "header"
                        tag.size_points = header_font_size(text_size - 2)
                    else
                        tag.size_points -= 2
                    end
                end
                redisplay
            end
        end

        def set_default_size
            self.tag_table.each do |tag|
                if tag.name == "header"
                    tag.size_points = header_font_size(DEFAULT_FONT_SIZE)
                else
                    tag.size_points = DEFAULT_FONT_SIZE
                end
            end
            redisplay
        end

        # Font name

        def font_name=(fn=nil)      
            unless self.font_name == fn
                fn = DEFAULT_FONT.to_s unless fn
                font_desc = Pango::FontDescription.new(fn)
                font_desc_big = font_desc.dup
                font_desc_big.size = header_font_size(font_desc.size)

                self.tag_table.each do |tag|
                    if tag.name == "header"
                        tag.font_desc = font_desc_big
                    else
                        tag.font_desc = font_desc
                    end
                end
                redisplay
            end
        end

        def font_name
            text_tag = self.tag_table.lookup("text")
            text_tag.font_desc.to_s
        end

        private

        def initialize_tags
            create_tag("header", :pixels_above_lines => 15,
                                 :pixels_below_lines => 15,
                                 :font_desc => DEFAULT_HEADER_FONT,
                                 :foreground => '#005500')

            create_tag("text", :foreground => '#000000',
                               :font_desc => DEFAULT_FONT)

            create_tag("link", :foreground => 'blue',
                               :underline  => Pango::AttrUnderline::SINGLE)
        end

        def header_font_size(font_size)
            (font_size * RATIO).round
        end

        def redisplay
            entries = @entries.dup
            self.clear
            entries.each do |type, txt|
                case type
                    when HEADER
                        insert_header(txt)
                    when TEXT
                        insert_text(txt)
                    when LINK
                        insert_link(txt)
                end
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
                        GLib::Type["VALUE"])
        
        def initialize
            super()
            self.buffer = LinkBuffer.new
            self.editable = false
            self.wrap_mode = Gtk::TextTag::WRAP_WORD
            self.cursor_visible = false
            self.left_margin = 3
            
            @hand_cursor = Gdk::Cursor.new(Gdk::Cursor::HAND2)
            @regular_cursor = Gdk::Cursor.new(Gdk::Cursor::XTERM)
            @hovering = false

            @press = nil

            initialize_signals

            show_all
        end

        private

        def initialize_signals
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
        end

        def follow_if_link(iter, event)
            iter.tags.each do |t|
                if t.name == "link"
                    start, limit = iter.dup, iter.dup
                    start.backward_to_tag_toggle(t)
                    limit.forward_to_tag_toggle(t)
                    word = start.get_text(limit)
                    Gtk.idle_add do
                        signal_emit("link_clicked", word, event)
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
                if t.name == "link"
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

        public
        
        def find_backward(str)
            return false if str.empty?

            last_search = self.buffer.get_mark("last-search-prev")

            start_iter, end_iter = self.buffer.bounds

            if last_search.nil?
                iter = end_iter
            else
                iter = self.buffer.get_iter_at_mark(last_search)
            end

            match_start, match_end = iter.backward_case_insensitive_search(
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
                # Place the cursor at the start when a new search is started
                self.buffer.place_cursor(start_iter)
            else
                iter = self.buffer.get_iter_at_mark(last_search)
            end

            match_start, match_end = iter.forward_case_insensitive_search(
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
