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

    def match_with_index_file(word, &comp)
        offsets = self.get_index_offsets

        found_indices = offsets.binary_search_all(word) do |offset, word|
            curr_word, curr_offset, curr_len = self.get_fields(offset)
            comp.call(curr_word, word)
        end

        found_offsets = found_indices.map { |i| offsets[i] }

        found_offsets.map { |offset| self.get_fields(offset) }
    end

    def match_exact(word)
        match_with_index_file(word) do |s1, s2|
            s1 <=> s2
        end
    end

    def match_prefix(word)
        match_with_index_file(word) do |s1, s2|
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

end
end