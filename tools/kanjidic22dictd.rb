# Kanjidic2 to dictd format converter
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

def puts_def(character)
    puts "_____\n\n#{character[:literal]}"
    puts " "
    puts "On-yomi : #{character[:readings][:ja_on].join(', ')}" \
        unless character[:readings].nil? or character[:readings][:ja_on].nil?

    puts "Kun-yomi : #{character[:readings][:ja_kun].join(', ')}" \
        unless character[:readings].nil? or character[:readings][:ja_kun].nil?

    puts "Pinyin: #{character[:readings][:pinyin].join(', ')}" \
        unless character[:readings].nil? or character[:readings][:pinyin].nil?

    puts "Meanings: #{character[:meanings].join(', ')}" \
        unless character[:meanings].nil?

    puts ""
    puts "Stroke count: #{character[:stroke_count]}" \
        unless character[:stroke_count].nil?

    puts "Frequence: #{character[:freq]}" \
        unless character[:freq].nil?

    puts "Grade: #{character[:grade]}" \
        unless character[:grade].nil?

    puts ""
end

begin
    require 'xml/parser'

    class ListenerAbstract < XML::Parser
    end
rescue LoadError
    require 'rexml/document'
    require 'rexml/streamlistener'

    class ListenerAbstract
        include REXML::StreamListener
    end
end

class Listener < ListenerAbstract
    
    def tag_start(name, attrs)
        @curr_tag = name
        @curr_attrs = attrs

        if name == "character"
            @character = {}

        elsif name == "rmgroup"
            @readings = {}
            @meanings = []
        end
    end
    alias :startElement :tag_start

    def tag_end(name)
        @parent_tag = name
        @curr_tag = nil

        if name == "character"
            puts_def(@character)

        elsif name == "rmgroup"
            @character[:meanings] = @meanings
            @character[:readings] = @readings
        end
    end
    alias :endElement :tag_end

    def text(txt)
        if ["literal", "grade", "stroke_count", "freq"].include? @curr_tag
            @character[@curr_tag.to_sym] = txt
        
        elsif @curr_tag == "reading"
            @readings[@curr_attrs['r_type'].to_sym] ||= []
            @readings[@curr_attrs['r_type'].to_sym] << txt

        elsif @curr_tag == "meaning" and not @curr_attrs.has_key? 'm_lang'
            @meanings << txt
        end
    end
    alias :character :text

end

def parse(file)
    list = Listener.new 
    
    if defined? XML::Parser
        list.parse(file.read)
    else
        REXML::Document.parse_stream(file, list)
    end
end

def usage
    puts ""
    puts "Usage"
    puts ""
    puts "ruby kanjidic22dictd.rb"
    puts ""
    puts "\tTakes Kanjidic2 as firt argument or on STDIN and outputs "
    puts "\tword definitons in a dictfmt compatible format."
    puts ""
    puts "\tThe produced output can be piped into the dictfmt utility. Ex:"
    puts ""
    puts "\tcat kanjidic2.gz | gunzip -c | ruby " + \
         "kanjidic22dictd.rb | dictfmt -c5 --utf8 -s \"Kanjidic2\" " + \
         "kanjidic2"
    puts ""
end

if $0 == __FILE__

    if ARGV.length == 1 and not ["-h", "--help"].include? ARGV[0]
        parse(File.new(ARGV[0]))
    elsif ARGV.length == 0
        parse($stdin)
    else
        usage
    end
end