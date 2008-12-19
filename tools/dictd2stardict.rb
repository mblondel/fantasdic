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

require "dictfmt"

def usage
    puts <<EOL
Usage:

ruby dictd2stardict.rb in-indexfile out-indexfile out-ifofile dicname

EOL
end

def get_dictd_entries(index_path)
    entries = []
    File.open(index_path) do |f|
        f.readlines.each do |line|
            entry = line.strip.split("\t")
            next if entry.length != 3
            kw, offs, len = entry
            entries << [kw, Dictfmt.b64_decode(offs), Dictfmt.b64_decode(len)]
        end
    end
    entries
end

def to_stardict_entry(kw, offs, len)
    kw + "\0" + [offs].pack("N") + [len].pack("N")
end

def ifo_file(bookname, wordcount, idxfilesize)
    return <<EOL
StarDict's dict ifo file
version=2.4.2
bookname=#{bookname}
wordcount=#{wordcount}
idxfilesize=#{idxfilesize}
sametypesequence=g
EOL
end


if $0 == __FILE__

    if ARGV.length != 4
        usage
    else
        in_indexfile = ARGV[0]
        out_indexfile = ARGV[1]
        out_ifofile = ARGV[2]
        dicname = ARGV[3]

        entries = get_dictd_entries(in_indexfile)

        File.open(out_indexfile, File::CREAT|File::RDWR) do |f|
            entries.each do |entry|
                f.write(to_stardict_entry(*entry))
            end
        end

        File.open(out_ifofile, File::CREAT|File::RDWR) do |f|
            f.write(ifo_file(dicname, entries.length, File.size(out_indexfile)))
        end
        
    end
end
