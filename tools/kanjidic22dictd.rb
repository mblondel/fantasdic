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

require "dictfmt"

def add_entry(character)
    txt = "#{character[:literal]}\n\n"
    txt += "On-yomi : #{character[:readings][:ja_on].join(', ')}\n" \
        unless character[:readings].nil? or character[:readings][:ja_on].nil?

    txt += "Kun-yomi : #{character[:readings][:ja_kun].join(', ')}\n" \
        unless character[:readings].nil? or character[:readings][:ja_kun].nil?

    txt += "Pinyin: #{character[:readings][:pinyin].join(', ')}\n" \
        unless character[:readings].nil? or character[:readings][:pinyin].nil?

    txt += "Meanings: #{character[:meanings].join(', ')}\n\n" \
        unless character[:meanings].nil?

    txt += ""
    txt += "Stroke count: #{character[:stroke_count].join(', ')}\n" \
        unless character[:stroke_count].nil?

    txt += "Frequence: #{character[:freq].join(', ')}\n" \
        unless character[:freq].nil?

    txt += "Grade: #{character[:grade].join(', ')}\n" \
        unless character[:grade].nil?

    kw = character[:literal]
    if character[:readings]
        kw += character[:readings][:ja_on] if character[:readings][:ja_on]
        kw += character[:readings][:ja_kun].collect do |j|
            m = j.match(/(.+)\.(.+)/)
            if m
                m[1]
            else
                j
            end
        end if character[:readings][:ja_kun]
        kw += character[:readings][:pinyin].collect do |p|
            p.gsub(/[1-5]*$/, "")
        end if character[:readings][:pinyin]
    end
    kw += character[:meanings] if character[:meanings]

    kw += character[:stroke_count].collect do |s|
        "stroke count: #{s}"
    end if character[:stroke_count]

    kw += character[:freq].collect do |f|
        "frequence: #{f}"
    end if character[:freq]

    kw += character[:grade].collect do |g|
        "grade: #{g}"
    end if character[:grade]

    $dictfmt.add_entry(kw, txt)
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
        elsif name == "strokes"
            
        elsif name == "rmgroup"
            @readings = {}
            @meanings = []
        elsif ["literal", "grade", "stroke_count", "freq"].include? @curr_tag
            @character[@curr_tag.to_sym] = []
        end
    end
    alias :startElement :tag_start

    def tag_end(name)
        @parent_tag = name
        @curr_tag = nil

        if name == "character"
            add_entry(@character)

        elsif name == "rmgroup"
            @character[:meanings] = @meanings
            @character[:readings] = @readings
        end
    end
    alias :endElement :tag_end

    def text(txt)
        if ["literal", "grade", "stroke_count", "freq"].include? @curr_tag
            @character[@curr_tag.to_sym] << txt
        
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
puts <<EOL
Usage: ruby kanjidic22dictd.rb dicname

The xml content is passed by STDIN.
EOL
end

if $0 == __FILE__
    if ARGV.length != 1
        usage
    else
        $dictfmt = Dictfmt.new("#{ARGV[0]}.index", "#{ARGV[0]}.dict", false)

        $dictfmt.set_utf8
        $dictfmt.set_shortname("Kanjidic2")
        $dictfmt.set_info("Blabla...")

        parse($stdin)

        $dictfmt.dictzip
    end
end