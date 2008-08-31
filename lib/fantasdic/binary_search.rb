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

class Array

    def binary_search(value, &comp)
        low = 0
        high = self.length - 1

        while low <= high
            mid = (low + high) / 2

            case comp.call(self[mid], value)
                when 1 # greater than
                    high = mid - 1
                when -1 # less than
                    low = mid + 1
                when 0 # equals
                    return mid
            end
        end
    end

    def binary_search_all(word, &comp)
        mid_offset = binary_search(word, &comp)

        if mid_offset
            arr = []

            (mid_offset - 1).downto(0) do |i|
                if comp.call(self[i], word) == 0
                    arr.push_head(i)
                else
                    break
                end
            end

            arr << mid_offset

            (mid_offset + 1).upto(self.length - 1) do |i|
                if comp.call(self[i], word) == 0
                    arr << i
                else
                    break
                end
            end

            arr
        else
            []
        end
    end

end

module Fantasdic

# Classes that include this module must be derived from File
# and define the following methods:
# 
# - get_prev_offset (instance method)
# - get_next_offset (instance method)
# - is_entry? (instance method)
# - get_fields (class method)
# - get_word_end (class method)
#
module FileBinarySearch

BUFFER_SIZE = 300

# Returns the first match found using the comp block for comparison.
def binary_search(word, &comp)
    low = 0
    file_size = File.size(self)
    high = file_size

    while low <= high
        mid = (low + high) / 2

        if is_entry?(mid)
            # by chance we hit the exact location of an entry
            start = mid
        else
            # mid is not exactly the offset of an entry
            # so we look for the closest entry before mid
            start = get_prev_offset(mid)
        end
        self.seek(start)

        buf = self.read(BUFFER_SIZE)
        return nil unless buf
        endd = self.class.get_word_end(buf)

        curr_word = buf.slice(0..endd)

        case comp.call(curr_word, word)
            when 1 # greater than
                high = get_prev_offset(start)
                return nil if high.nil?
            when -1 # less than
                low = get_next_offset(start)
                return nil if low.nil?
            when 0 # equals
                return start
        end
    end

    nil
end

def binary_search_all(word, &comp)
    mid_offset = binary_search(word, &comp)

    if mid_offset
        # Since binary_search only returns one match,
        # we have to look for possible other matches before and after

        arr = []

        # before
        offset = mid_offset
        while true
            prev_offset = get_prev_offset(offset)
            break if prev_offset.nil?
            len = offset - prev_offset

            fields = get_fields(prev_offset, len)
            curr_word = fields.first

            break if comp.call(curr_word, word) != 0

            arr.push_head(fields)

            offset = prev_offset
        end

        # after
        offset = mid_offset
        while true
            next_offset = get_next_offset(offset)
            break if next_offset.nil?
            len = next_offset - offset

            fields = get_fields(offset, len)
            curr_word = fields.first

            break if comp.call(curr_word, word) != 0

            arr << fields

            offset = next_offset
        end

        arr
    else
        []
    end
end

def get_fields(offset, len)
    self.seek(offset)
    buf = self.read(len)
    self.class.get_fields(buf)
end


end
end