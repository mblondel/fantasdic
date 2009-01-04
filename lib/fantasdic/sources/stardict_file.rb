# Fantasdic
# Copyright (C) 2008-2009 Mathieu Blondel
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

class StardictInfo < Hash

    def initialize(file_path)
        File.open(file_path) { |f| parse(f) }
    end

    private

    def parse(f)
        f.each_line do |line|
            key, value = line.strip.split("=").map { |s| s.strip }
            next if value.nil?
            if ["wordcount", "idxfilesize"].include?(key)
                self[key] = value.to_i
            else
                self[key] = value
            end
        end
    end

end

class StardictIndex < File

    OFFSET_INT_SIZE = 4
    LEN_INT_SIZE = 4

    def initialize(*args)
        super(*args)
    end

    def open(*args)
        super(*args)
    end

    def self.get_fields(str)
        i = str.index("\0")
        word = str.slice(0...i)
        word_offset = str.slice((i+1)..(i+OFFSET_INT_SIZE))
        word_len = \
            str.slice((i+OFFSET_INT_SIZE+1)..(i+OFFSET_INT_SIZE+LEN_INT_SIZE))

        word_offset = word_offset.nbo32_to_integer
        word_len = word_len.nbo32_to_integer

        [word, word_offset, word_len]
    end

    def get_fields(offset, len=0)
        self.seek(offset)
        if len > 0
            buf = self.read(len)
        else
            # we don't know the size so we read the maximum entry size
            buf = self.read(256 + 1 + OFFSET_INT_SIZE + LEN_INT_SIZE)
        end
        self.class.get_fields(buf)
    end

    def match_binary_search(word, &comp)
        offsets = self.get_index_offsets

        found_indices = offsets.binary_search_all(word) do |offset, word|
            curr_word, curr_offset, curr_len = self.get_fields(offset)
            comp.call(curr_word.downcase, word.downcase)
        end

        found_offsets = found_indices.map { |i| offsets[i] }

        found_offsets.map { |offset| self.get_fields(offset) }
    end

    def match_exact(word)
        match_binary_search(word) do |s1, s2|
            s1 <=> s2
        end
    end

    def match_prefix(word)
        match_binary_search(word) do |s1, s2|
            if s1 =~ /^#{s2}/
                0
            else
                s1 <=> s2
            end
        end
    end

    def match_suffix(word)
        get_word_list.find_all do |curr_word, offset, len|
            curr_word =~ /#{word}$/
        end
    end

    def match_substring(word)
        get_word_list.find_all do |curr_word, offset, len|
            curr_word.include?(word)
        end
    end

    def match_word(word)
        match_substring(word).find_all do |curr_word, offset, len|
            ret = false
            curr_word.split(" ").each do |single_word|
                if single_word == word
                    ret = true
                    break
                end
            end
            ret
        end         
    end

    # Returns the offsets of the beginning of each entry in the index
    def get_index_offsets
        self.rewind
        buf = self.read # FIXME: don't load the whole index into memory
        len = buf.length
        offset = 0

        offsets = []

        while offset < len
            offsets << offset
            i = buf.index("\0", offset)
            offset = i + OFFSET_INT_SIZE + LEN_INT_SIZE + 1
        end

        offsets
    end

    def get_word_list
        self.rewind
        buf = self.read # FIXME: don't load the whole index into memory
        len = buf.length
        offset = 0

        words = []

        while offset < len
            i = buf.index("\0", offset)
            end_offset = i + OFFSET_INT_SIZE + LEN_INT_SIZE
            words << StardictIndex.get_fields(buf.slice(offset..end_offset))
            offset = end_offset + 1
        end

        words
    end

end

class StardictFile < Base

    authors ["Mathieu Blondel"]
    title  _("Stardict file")
    description _("Look up words in Stardict files.")
    license Fantasdic::GPL
    copyright "Copyright (C) 2008-2009 Mathieu Blondel"
    no_databases true   

    STRATEGIES_DESC = {
        "define" => "Results match with the word exactly.",
        "prefix" => "Results match with the beginning of the word.",
        "word" => "Results have one word that match with the word.",
        "substring" => "Results have a portion that contains the word.",
        "suffix" => "Results match with the end of the word."
    }

    class ConfigWidget < FileSource::ConfigWidget

        def initialize(*args)
            super(*args)

            @choose_file_message = _("Select a dictd file")
            @file_extensions = [["*.ifo", _("Ifo files")]]
            @encodings = []

            initialize_ui
            initialize_data
            initialize_signals
        end

    end

    def check_validity
        n_errors = 0
        n_lines = 0

        stardict_file_open do |index_file, dict_file|
            index_file.get_index_offsets.each do |offset|
                n_errors += 1 if not offset.is_a? Fixnum
                n_lines += 1
            end
        end

        if (n_errors.to_f / n_lines) >= 0.2
            raise Source::SourceError,
                    _("The associated index file is not valid!")
        end
    end

    def available_strategies
        STRATEGIES_DESC
    end

    def define(db, word)        
        db = File.basename(@config[:filename]).slice(0...-6)
        db_capitalize = db.capitalize

        stardict_file_open do |index_file, dict_file|
            index_file.match_exact(word).map do |match, offset, len|
                defi = Definition.new
                defi.word = match
                defi.body = get_definition(dict_file, offset, len).strip
                defi.database = db
                defi.description = db_capitalize
                defi
            end
        end
    end

    def match(db, strat, word)
        matches = []

        stardict_file_open do |index_file, dict_file|
            matches = case strat
                when "prefix", "suffix", "substring", "word"
                    index_file.send("match_#{strat}", word)
                else
                    []
            end.map do |match, offset, len|
                match
            end
        end

        hsh = {}
        db = File.basename(@config[:filename])
        hsh[db] = matches unless matches.empty?
        hsh
    end

    private

    def get_definition(file, offset, len)
        file.pos = offset
        file.read(len)
    end

    def stardict_file_open
        idx_file = @config[:filename].gsub(/.ifo/, ".idx")
        dict_file = @config[:filename].gsub(/.ifo/, ".dict")
        dict_gz_file = dict_file + ".dz"

        [@config[:filename], idx_file].each do |mandatory_file|
            if !File.readable? mandatory_file
                raise Source::SourceError,
                        _("Cannot open file %s.") % mandatory_file
            end
        end

        if !File.readable? dict_file and !File.readable? dict_gz_file
            raise Source::SourceError,
            _("Couldn't find .dict or .dict.dz dictionary file.")
        elsif File.readable? dict_file
            dict_file = File.new(dict_file)
        else
            begin
                dict_file = Dictzip.new(dict_gz_file)
            rescue DictzipError => e
                raise Source::SourceError, e.to_s
            end
        end

        index_file = StardictIndex.new(idx_file)

        if block_given?
            ret = yield(index_file, dict_file) 

            index_file.close
            dict_file.close

            ret
        else
            [index_file, dict_file]
        end
    end

end

end
end

Fantasdic::Source::Base.register_source(Fantasdic::Source::StardictFile)