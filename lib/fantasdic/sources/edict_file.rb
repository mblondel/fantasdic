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

class EdictFileBase < FileSource

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

    class ConfigWidget < FileSource::ConfigWidget

        def initialize(*args)
            super(*args)

            @choose_file_message = _("Select an EDICT file")
            @file_extensions = [["*.gz", _("Gzip-compressed files")]]
            @encodings = ["UTF-8", "EUC-JP"]

            initialize_ui
            initialize_data
            initialize_signals

            unless HAVE_EGREP
                @encoding_combobox.sensitive = false
            end
        end

    end

    def check_validity
        n_errors = 0
        n_lines = 0
        begin
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
        rescue Zlib::GzipFile::Error => e
            raise Source::SourceError,
                    _("This file is not a valid EDICT file!")
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
            regexp = "/#{wesc}/"
        elsif word.kana?
            regexp = "^#{wesc} |\\[#{wesc}\\]"
        elsif word.japanese?
            regexp = "^#{wesc} "
        else
            regexp = "^#{wesc}|\\[#{wesc}\\]|/#{wesc}/"
        end
        
        db = File.basename(@hash[:filename])
        db_capitalize = db.capitalize

        match_with_regexp(regexp).map do |line|
            defi = Definition.new
            defi.word = word
            defi.body = line.strip
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
        match_substring(db, word).each do |line|
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
            regexp = "/#{wesc}"
        elsif word.kana?
            regexp = "^#{wesc}| \\[#{wesc}"
        elsif word.japanese?
            regexp = "^#{wesc}"
        else
            regexp = "^#{wesc}|\\[#{wesc}|/#{wesc}"
        end

        match_with_regexp(regexp)
    end

    def match_suffix(db, word)
        wesc = escape_string(word)
        if word.latin?
            regexp = "#{wesc}/"
        elsif word.kana?
            regexp = "#{wesc} \\[|#{wesc}\\]"
        elsif word.japanese?
            regexp = "#{wesc} \\["
        else
            regexp = "#{wesc} \\[|#{wesc}\\]|#{wesc}/"
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
            begin
                file = Zlib::GzipReader.new(File.new(@hash[:filename]))
            rescue Zlib::GzipFile::Error => e
                raise Source::SourceError,
                    _("This file is not a valid EDICT file!")
            end
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

end # class EdictFileBase


# Using egrep. This is significantly faster!
class EdictFileEgrep < EdictFileBase
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

# Pure Ruby
class EdictFileRuby < EdictFileBase
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

class EdictFile < (EdictFileBase::HAVE_EGREP ? EdictFileEgrep : EdictFileRuby)
    authors ["Mathieu Blondel"]
    title  _("EDICT file")
    description _("Look up words in an EDICT file.")
    license Fantasdic::GPL
    copyright "Copyright (C) 2007 Mathieu Blondel"
    no_databases true    
end

end
end

Fantasdic::Source::Base.register_source(Fantasdic::Source::EdictFile)
