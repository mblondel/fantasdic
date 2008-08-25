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

    def utf8_reverse
        self.unpack("U*").reverse.pack("U*")
    end

    def latin?
        self.unpack("U*").each do |char|
            if not (char >= 0 and char <= 0x00FF)
                return false 
            end
        end
        return true
    end

    def kanji?
        self.unpack("U*").each do |char|
            if not (
                    (char >= 0x4E00 and char <= 0x9FBF) or
                    (char >= 0x3400 and char <= 0x4DBF) or
                    (char >= 0x20000 and char <= 0x2A6DF) or
                    (char >= 0x3190 and char <= 0x319F) or
                    (char >= 0xF900 and char <= 0xFAFF) or
                    (char >= 0x2F800 and char <= 0x2FA1F)
                   )
                return false 
            end
        end
        return true
    end

    def hiragana?
        self.unpack("U*").each do |char|
            if not (char >= 0x3040 and char <= 0x309F)
                return false
            end
        end
        return true
    end
  
    def katakana?
        self.unpack("U*").each do |char|
            if not (char >= 0x30A0 and char <= 0x30FF)
                return false
            end
        end
        return true
    end
  
    def kana?
        self.unpack("U*").each do |char|
            if not ((char >= 0x30A0 and char <= 0x30FF) or
                    (char >= 0x3040 and char <= 0x309F))
                return false
            end
        end
        return true
    end

    def japanese?
        self.unpack("U*").each do |char|
            if not (
                    (char >= 0x4E00 and char <= 0x9FBF) or
                    (char >= 0x3400 and char <= 0x4DBF) or
                    (char >= 0x20000 and char <= 0x2A6DF) or
                    (char >= 0x3190 and char <= 0x319F) or
                    (char >= 0xF900 and char <= 0xFAFF) or
                    (char >= 0x2F800 and char <= 0x2FA1F) or
                    (char >= 0x30A0 and char <= 0x30FF) or
                    (char >= 0x3040 and char <= 0x309F)
                   )
                return false 
            end
        end
        return true
    end
end

class Array
    def push_head(ele)
        self.insert(0, ele)
        self
    end

    def push_tail(ele)
        self << ele
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

class File
    if /mingw|mswin|win32/ =~ RUBY_PLATFORM
        LOAD_PATH_SEPARATOR = ";"
    else
        LOAD_PATH_SEPARATOR = ":"
    end

    def self.which(pgm)        
        ENV['PATH'].split(LOAD_PATH_SEPARATOR).each do |dir|
            path = File.join(dir, pgm)
            return path if File.executable? path
        end
        return nil
    end
end

class Symbol
    def to_proc
        Proc.new { |*args| args.shift.send(self, *args) }
    end
end

module Enumerable

    def sum(identity = 0, &block)
        return identity unless size > 0

        if block_given?
            map(&block).sum
        else
            inject { |sum, element| sum + element }
        end
    end

end