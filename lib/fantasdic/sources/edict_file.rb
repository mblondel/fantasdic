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

require "zlib"

module Fantasdic
module Source

class EdictFile < Base
    authors ["Mathieu Blondel"]
    title  _("EDICT file")
    description _("Look up words in an EDICT file.")
    license UI::AboutDialog::GPL
    copyright "Copyright (C) 2007 Mathieu Blondel"
    no_databases true

    STRATEGIES_DESC = {
        "define" => "Results match with the word exactly.",
        "prefix" => "Results match with the beginning of the word.",
        "word" => "Results have one word that match with the word.",
        "substring" => "Results have a portion that contains the word.",
        "suffix" => "Results match with the end of the word."
    }

    REGEXP_WORD = '([^\[\/ ]+)'
    REGEXP_READING = '( \[([^\]\/ ]+)\])?'
    REGEXP_TRANSLATIONS = ' /(.+)/'
    REGEXP = Regexp.new('^' + REGEXP_WORD + REGEXP_READING +
                         REGEXP_TRANSLATIONS)

    HAVE_EGREP = (File.which("egrep") and File.which("iconv") and
                  File.which("gunzip") and File.which("cat"))


    class ConfigWidget < Base::ConfigWidget
        def initialize(*arg)
            super(*arg)
            initialize_ui
            initialize_data
            initialize_signals
        end

        def to_hash
            if !@file_chooser_button.filename
                raise Source::SourceError, _("A file must be selected!")
            end
            hash = {
                :filename => @file_chooser_button.filename,
                :encoding => selected_encoding
            }
            EdictFile.new(hash).check_validity
            hash
        end

        private

        def initialize_ui
            @file_chooser_button = Gtk::FileChooserButton.new(
                _("Select an EDICT file"),
                Gtk::FileChooser::ACTION_OPEN)

            filter = Gtk::FileFilter.new
            filter.add_pattern("*")
            filter.name = _("All files")

            @file_chooser_button.add_filter(filter)

            filter = Gtk::FileFilter.new
            filter.add_pattern("*.gz")
            filter.name = _("Gzip-compressed files")

            @file_chooser_button.add_filter(filter)

            @encoding_combobox = Gtk::ComboBox.new(true)
            @encoding_combobox.append_text("UTF-8")
            @encoding_combobox.append_text("EUC-JP")

            unless HAVE_EGREP
                @encoding_combobox.sensitive = false
            end

            file_label = Gtk::Label.new(_("_File:"), true)
            file_label.xalign = 0
            encoding_label = Gtk::Label.new(_("_Encoding:"), true)
            encoding_label.xalign = 0

            table = Gtk::Table.new(2, 2)
            table.row_spacings = 6
            table.column_spacings = 12
            # attach(child, left, right, top, bottom,
            #        xopt = Gtk::EXPAND|Gtk::FILL,
            #        yopt = Gtk::EXPAND|Gtk::FILL, xpad = 0, ypad = 0)
            table.attach(file_label, 0, 1, 0, 1, Gtk::FILL, Gtk::FILL)
            table.attach(encoding_label, 0, 1, 1, 2, Gtk::FILL, Gtk::FILL)
            table.attach(@file_chooser_button, 1, 2, 0, 1)
            table.attach(@encoding_combobox, 1, 2, 1, 2)

            self.pack_start(table)
        end

        def initialize_data
            if @hash
                if @hash[:filename]
                    @file_chooser_button.filename = @hash[:filename]
                end
                if @hash[:encoding]
                    case @hash[:encoding]
                        when "UTF-8"
                            @encoding_combobox.active = 0
                        when "EUC-JP"
                            @encoding_combobox.active = 1
                    end
                end
            end
            if !@hash or !@hash[:encoding]
                @encoding_combobox.active = 0
            end
        end

        def initialize_signals
            @file_chooser_button.signal_connect("selection-changed") do
                @on_databases_changed_block.call
            end

            @encoding_combobox.signal_connect("changed") do
                if @file_chooser_button.filename
                    @on_databases_changed_block.call
                end
            end
        end

        def selected_encoding
            n = @encoding_combobox.active
            @encoding_combobox.model.get_iter(n.to_s)[0] if n >= 0
        end

    end # class ConfigWidget

    def check_validity
        n_errors = 0
        n_lines = 0
        edict_file_open do |file|
            file.each_line do |line|
                if @hash[:encoding] and @hash[:encoding] != "UTF-8"
                    line = convert_to_utf8(@hash[:encoding], line)
                end
                n_errors += 1 if REGEXP.match(line).nil?
                n_lines += 1
                break if n_lines >= 20
            end
        end
        if (n_errors.to_f / n_lines) >= 0.2
            raise Source::SourceError,
                    _("This file is not a valid EDICT file!")
        end
    end

    def available_strategies
        STRATEGIES_DESC
    end

    def define(db, word)
        wesc = escape_string(word)

        if word.latin?
            regexp = "\/#{wesc}\/"
        elsif word.kana?
            regexp = "^#{wesc} |\[#{wesc}\]"
        elsif word.japanese?
            regexp = "^#{wesc} "
        else
            regexp = "^#{wesc}|\[#{wesc}\]|\/#{wesc}\/"
        end
        
        db = File.basename(@hash[:filename])
        db_capitalize = db.capitalize

        match_with_regexp(regexp).map do |line|
            defi = Definition.new
            defi.word = word
            defi.body = line
            defi.database = db
            defi.description = db_capitalize
            defi
        end
    end

    def match(db, strat, word)
        arr_lines = case strat
            when "prefix", "suffix", "substring", "word"
                send("match_#{strat}", db, word)
            else
                []
        end

        arr = arr_lines.map do |line|
            found_word, found_reading, found_trans = get_fields(line)
            if word.kana? or word.japanese?
                found_word
            else
                found_trans
            end
        end

        hsh = {}
        db = File.basename(@hash[:filename])
        hsh[db] = arr unless arr.empty?
        hsh
    end

    private

    def match_word(db, word)
        arr = []
        match_suffix(db, word).each do |line|
            get_fields(line).each do |field|
                field.split(" ").each do |w|
                    if w ==  word
                        arr << line
                        break
                    end
                end if field
            end
        end
        arr.uniq!
        arr
    end

    def match_prefix(db, word)
        wesc = escape_string(word)
        if word.latin?
            regexp = "\/#{wesc}[^\/]*\/"
        elsif word.kana?
            regexp = "^#{wesc}|\[#{wesc}[^\]]*\]"
        elsif word.japanese?
            regexp = "^#{wesc}"
        else
            regexp = "^#{wesc}|\[#{wesc}[^\]]*\]|\/#{wesc}[^\/]*\/"
        end

        match_with_regexp(regexp)
    end

    def match_suffix(db, word)
        wesc = escape_string(word)
        if word.latin?
            regexp = "\/[^\/]*#{wesc}\/"
        elsif word.kana?
            regexp = "^[^\[]*#{wesc} |\[[^\]]*#{wesc}\]"
        elsif word.japanese?
            regexp = "^[^\[]*#{wesc} "
        else
            regexp = "^[^\[]*#{wesc} |\[[^\]]*#{wesc}\]|\/[^\/]*#{wesc}\/"
        end

        match_with_regexp(regexp)
    end

    def match_substring(db, word)
        wesc = escape_string(word)
        match_with_regexp(wesc)
    end

    def edict_file_open
        if !File.readable? @hash[:filename]
            raise Source::SourceError,
                    _("Cannot open file %s.") % @hash[:filename]
        end
        if @hash[:filename] =~ /.gz$/
            file = Zlib::GzipReader.new(File.new(@hash[:filename]))
        else
            file = File.new(@hash[:filename])
        end

        if block_given?
            ret = yield(file)

            file.close

            ret
        else
            file
        end
    end

    def get_fields(line)
        m = REGEXP.match(line)
        if m
            [m[1], m[3], m[4]]
        else
            nil
        end
    end

    def escape_string(str)
        Regexp.escape(str).sub('"', "\\\"")
    end

end # class EdictFile

if EdictFile::HAVE_EGREP
    # Using egrep. This is significantly faster!
    class EdictFile
        def initialize(*args)
            super(*args)
            edict_file_open.close # Tries to open file to ensure it exists
        end

        private

        def match_with_regexp(regexp)
            cmd = get_command(regexp)            
            IO.popen(cmd).readlines
        end

        def get_command(regexp)
            cmd = []

            cmd << "cat #{@hash[:filename]}"

            if @hash[:filename] =~ /.gz$/
                cmd << "gunzip -c"
            end

            if @hash[:encoding] and @hash[:encoding] != "UTF-8"
                cmd << "iconv -f #{@hash[:encoding]} -t UTF-8"
            end

            cmd << "egrep \"#{regexp}\""
            
            cmd.join(" | ")
        end

    end

else
    # Pure Ruby
    class EdictFile
        def initialize(*args)
            super(*args)
            if @hash and @hash[:encoding] != "UTF-8"
                # FIXME: Find a way to look up words in EUC-JP with reasonable
                # performance...
                raise Source::SourceError,
                      _("Encoding not supported.")
            end
        end

        private

        def match_with_regexp(regexp)
            edict_file_open do |file|
                file.grep(Regexp.new(regexp))
            end
        end

    end

end # if EdictFile::HAVE_EGREP

end
end
