# Tanaka Corpus to dictd format converter
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

$KCODE = 'u'

def puts_def(headword, examples)
    puts "_____\n\n#{headword}"
    puts " "

    examples.each do |japanese, english|
        puts japanese
        puts "#{english}\n\n"
    end

    puts " "
end

def parse_word(word)
    wd = ""
    conj_form = ""
    reading = ""
    sense_num = ""

    in_wd = true
    in_conj_form = false
    in_reading = false
    in_sense_num = false

    word.split(//).each do |char|
        if char == "{"
            in_wd = false
            in_conj_form = true
            next
        elsif char == "}"
            in_conj_form = false
            next
        elsif char == "("
            in_wd = false
            in_reading = true
            next
        elsif char == ")"
            in_reading = false
            next
        elsif char == "["
            in_wd = false
            in_sense_num = true
            next
        elsif char == "]"
            in_wd = false
            in_sense_num = false
            next
        end

        if in_wd
            wd += char
        elsif in_conj_form
            conj_form += char
        elsif in_reading
            reading += char
        elsif in_sense_num
            sense_num += char
        end
            
    end

    hsh = {}
    hsh[:wd] = wd unless wd.empty?
    hsh[:conj_form] = conj_form unless wd.empty?
    hsh[:reading] = reading unless wd.empty?
    hsh[:sense_num] = sense_num unless wd.empty?

    hsh
end

def parse
    i = 0

    word_list = {}

    japanese = ""
    english = ""

    $stdin.each_line do |line|
        if line =~ /^A: /
            japanese, english = line.slice(3...-1).split("\t")
        elsif line =~ /^B: /
            words = line.slice(3...-1).split(" ")    

            words.each do |word|
                wd = parse_word(word)[:wd]
                word_list[wd] ||= []
                word_list[wd] << [japanese, english]
            end

            japanese = ""
            english = ""
        end

        i += 1
    end

    word_list.each do |headword, examples|
        puts_def(headword, examples)
    end
end

def usage
    puts ""
    puts "Usage"
    puts ""
    puts "ruby tanakacorpus2dictd.rb"
    puts ""
    puts "\tTakes the tanaka corpus on STDIN and outputs "
    puts "\tword definitons in a dictfmt compatible format."
    puts ""
    puts "\tThe produced output can be piped into the dictfmt utility. Ex:"
    puts ""
    puts "\tcat examples.gz | gunzip -c | iconv -f EUCJP -t UTF8 | ruby " + \
         "tanakacorpus2dictd.rb | dictfmt -c5 --utf8 -s \"Tanaka Corpus\" " + \
         "tanakacorpus"
    puts ""

end

if $0 == __FILE__

    if ARGV.length > 0
        usage
    else
        parse
    end
end