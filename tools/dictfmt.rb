# Dictfmt: build dictionaries for dictd with Ruby
# Copyright (C) 2007 Mathieu Blondel
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

$KCODE="u"

class Dictfmt

    INFO_HEADWORD = "00-database-info"
    SHORT_HEADWORD = "00-database-short"
    URL_HEADWORD = "00-database-url"
    UTF8_HEADWORD = "00-database-utf8"

    B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".
          split(//)

    def self.b64_encode(val)
        startfound = 0
        retval = ""
        5.downto(0) do |i|
            thispart = (val >> (6 * i)) & ((2 ** 6) - 1)
            next if startfound == 0 and thispart == 0
            startfound = 1
            retval += B64[thispart]                
        end
        if retval.empty?
            B64[0]
        else
            retval
        end
    end

    def self.b64_decode(str)
        str = str.split(//)
        return 0 if str.length == 0

        retval = 0
        shiftval = 0

        (str.length - 1).downto(0) do |i|
            val = B64.index(str[i])
            retval = retval | (val << shiftval)
            shiftval += 6
        end
        retval
    end

    def format_kw(kw)
        kw.gsub!(/(\"|\(|\)|\'|\,|\.|^\-)/, "")
        kw = kw.chomp.strip.downcase        
    end

    def initialize(index_path, dic_path, quiet=true)
        @current_offset = 0
        @index_path = index_path
        @dic_path = dic_path
        @dic_file = File.new(dic_path, File::CREAT|File::RDWR)
        @quiet = quiet
        @processed = 0
        @index = IO.popen(
            "LC_COLLATE=C sort -t \"\t\" -k 1,3 > #{@index_path}",
            "w")
    end

    def set_info(info)
        add_entry([INFO_HEADWORD], INFO_HEADWORD + "\n" + info)
    end

    def set_utf8
        add_entry([UTF8_HEADWORD], "\n")
    end

    def set_url(url)
        add_entry([URL_HEADWORD], URL_HEADWORD + "\n     " + url)
    end

    def set_shortname(shortname)
        add_entry([SHORT_HEADWORD], SHORT_HEADWORD + "\n     " + shortname)
    end

    def add_entry(keywords, text)
        text += "\n" if text !~ /\n$/
        len = text.length

        keywords.each do |k|
            k = format_kw(k)
            next if k.empty?
            @index.write "%s\t%s\t" % [k, Dictfmt::b64_encode(@current_offset)]
            @index.write "%s\n" % Dictfmt::b64_encode(len)
            @processed += 1
        end

        @current_offset += len
        @dic_file.write(text)
        

        if @processed % 50 == 0 and !@quiet
            $stderr.write "%10d headwords\r" % @processed
        end
    end

    def dictzip
        $stderr.write "\nCompressing dictionary \n" unless @quiet
        `dictzip #{@dic_path}`
    end

end
