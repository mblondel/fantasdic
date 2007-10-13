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

class String
    def utf8_length
        self.unpack("U*").length
    end

    def utf8_slice(range)
        self.unpack("U*")[range].pack("U*")
    end
end

class Array
    def push_head(ele)
        self << ele
        self
    end

    def push_tail(ele)
        self[self.length] = ele
        self
    end

    def pop_head
        self.delete_at(0)
    end

    def pop_tail
        if self.length == 0
            nil
        else
            self.delete_at(self.length - 1)
        end
    end
end