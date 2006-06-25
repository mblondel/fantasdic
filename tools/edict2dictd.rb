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

# Usage :
#
# cat edict.gz | gunzip -c | iconv -f EUCJP -t UTF8 | ruby edict2dictd.rb \ |
# dictfmt -c5 --utf8 -s "Dict name" dictname

def puts_def(word, reading, meanings)
    puts "_____\n\n#{word}"
    puts " "
    puts reading unless reading.nil?
    puts meanings.join(', ')
    puts " "

    unless reading.nil?
        puts "_____\n\n#{reading}"
        puts " "
        puts word
        puts meanings.join(', ')
        puts " "
    end

    meanings.each do |meaning|
        meaning.split(', ').each do |sense|
            #sense.split(' ').each do |sense_word|
                puts "_____\n\n#{sense}"
                puts " "
                puts word
                puts reading unless reading.nil?
                puts meanings.join(', ')
                puts " "
            #end
        end
    end
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
    puts ""
    puts "Usage"
    puts ""
    puts "ruby edict2dictd.rb"
    puts ""
    puts "\tTakes content in EDICT format on STDIN and outputs "
    puts "\tword definitons in a dictfmt compatible format."
    puts ""
    puts "\tThe produced output can be piped into the dictfmt utility. Ex:"
    puts ""
    puts "\tcat edict.gz | gunzip -c | iconv -f EUCJP -t UTF8 | ruby " + \
         "edict2dictd.rb | dictfmt -c5 --utf8 -s \"Dict name\" dictname"
    puts ""

end

if $0 == __FILE__

    if ARGV.length > 0
        usage
    else
        parse
    end
end