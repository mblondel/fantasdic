# EDICT to dictd format converter
# Copyright (C) 2006 Mathieu Blondel
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

require "dictfmt"

def puts_def(word, reading, meanings)
    txt = "#{word} \n\n"
    txt += "Reading: #{reading}\n" if reading
    txt += "Meanings: #{meanings.join(', ')} \n\n"

    kw = [word]
    kw << reading if reading
    kw += meanings

    $dictfmt.add_entry(kw, txt)
end

def parse
    i = 0
    $stdin.each_line do |line|
        word, *meanings = line.split('/')
        word.strip!
    
        word, reading = word.split(' ')
        reading = reading.slice(1...-1) unless reading.nil?
    
        puts_def word, reading, meanings

        i += 1
    end
end

def usage
puts <<EOL
Usage: ruby edict2dictd.rb dicname

Takes content in EDICT format on STDIN.

You may have to convert EDICT from EUCJP to UTF8. ex:

gunzip -c edict.gz | iconv -f EUCJP -t UTF8 | ruby edict2dictd.rb dicname
EOL
end

if $0 == __FILE__

    if ARGV.length != 1
        usage
    else
        $dictfmt = Dictfmt.new("#{ARGV[0]}.index", "#{ARGV[0]}.dict", false)

        $dictfmt.set_utf8
        $dictfmt.set_shortname(ARGV[0].capitalize)
        $dictfmt.set_info("See http://www.csse.monash.edu.au/~jwb/j_edict.html")

        parse

        $dictfmt.dictzip
    end
end