# Fantasdic
# Copyright (C) 2008 Mathieu Blondel
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
module Source

class FileSource < Base

    class ConfigWidget < Base::ConfigWidget
        def initialize(*arg)
            super(*arg)

            @file_extensions = [] # each element must contain [ext, desc]
            @encodings = []
            @choose_file_message = _("Select a file")
        end

        def to_hash
            if !@file_chooser_button.filename
                raise Source::SourceError, _("A file must be selected!")
            end

            hash = {
                :filename => @file_chooser_button.filename,  
            }

            if @encodings.length > 0
                hash[:encoding] = selected_encoding
            end

            klass = self.class
            src_class = eval(klass.to_s.split("::").slice(0...-1).join("::"))
            src_class.new(hash).check_validity
            hash
        end

        private

        def initialize_ui
            @file_chooser_button = Gtk::FileChooserButton.new(
                @choose_file_message,
                Gtk::FileChooser::ACTION_OPEN)

            @file_extensions.each do |ext, desc|
                filter = Gtk::FileFilter.new
                filter.add_pattern(ext)
                filter.name = desc

                @file_chooser_button.add_filter(filter)
            end

            filter = Gtk::FileFilter.new
            filter.add_pattern("*")
            filter.name = _("All files")

            @file_chooser_button.add_filter(filter)

            file_label = Gtk::Label.new(_("_File:"), true)
            file_label.xalign = 0

            table = Gtk::Table.new(2, 2)
            table.row_spacings = 6
            table.column_spacings = 12
            # attach(child, left, right, top, bottom,
            #        xopt = Gtk::EXPAND|Gtk::FILL,
            #        yopt = Gtk::EXPAND|Gtk::FILL, xpad = 0, ypad = 0)
            table.attach(file_label, 0, 1, 0, 1, Gtk::FILL, Gtk::FILL)
            table.attach(@file_chooser_button, 1, 2, 0, 1)

            if @encodings.length > 0
                @encoding_combobox = Gtk::ComboBox.new(true)
                @encodings.each do |encoding|
                    @encoding_combobox.append_text(encoding)
                end

                encoding_label = Gtk::Label.new(_("_Encoding:"), true)
                encoding_label.xalign = 0

                table.attach(encoding_label, 0, 1, 1, 2, Gtk::FILL, Gtk::FILL)
                table.attach(@encoding_combobox, 1, 2, 1, 2)
            end

            self.pack_start(table)
        end

        def initialize_data
            if @hash
                if @hash[:filename]
                    @file_chooser_button.filename = @hash[:filename]
                end

                if @encodings.length > 0
                    if @hash[:encoding]
                        case @hash[:encoding]
                            when "UTF-8"
                                @encoding_combobox.active = 0
                            when "EUC-JP"
                                @encoding_combobox.active = 1
                        end
                    end
                end
            end

            if @encodings.length > 0 and (!@hash or !@hash[:encoding])
                @encoding_combobox.active = 0
            end
        end

        def initialize_signals
            @file_chooser_button.signal_connect("selection-changed") do
                @on_databases_changed_block.call
            end

            if @encodings.length > 0
                @encoding_combobox.signal_connect("changed") do
                    if @file_chooser_button.filename
                        @on_databases_changed_block.call
                    end
                end
            end
        end

        def selected_encoding
            n = @encoding_combobox.active
            @encoding_combobox.model.get_iter(n.to_s)[0] if n >= 0
        end

    end # class ConfigWidget

end

end
end