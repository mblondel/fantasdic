# JMnedict to dictd format converter
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

require "dictfmt"

def add_entry(entry)
    txt = ""
    txt += @entry[:kanji].join(', ') + "\n\n" if @entry[:kanji]
    txt += "Reading: " + @entry[:readings].join(', ') + "\n" \
        if @entry[:readings]
    txt += "Name type: " + @entry[:name_type].join(', ') + "\n" \
        if @entry[:name_type]
    txt += "Translation: " + @entry[:translation].join(', ') + "\n" \
        if @entry[:translation]

    kw = []
    [:kanji, :readings, :translation].each do |k|
        kw += @entry[k] if @entry[k]
    end    
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

        if name == "entry"
            @entry = {}
        elsif name == "k_ele"
            @entry[:kanji] = []
        elsif name == "r_ele"
            @entry[:readings] = []
        elsif name == "name_type"
            @entry[:name_type] ||= []
        elsif name == "trans_det"
            @entry[:translation] ||= []
        end
    end
    alias :startElement :tag_start

    def tag_end(name)
        if name == "entry"
            add_entry(@entry)
        end
    end
    alias :endElement :tag_end

    def text(txt)
        txt = txt.chomp.strip
        return if txt.empty?
        if @curr_tag == "keb"
            @entry[:kanji] << txt
        elsif @curr_tag == "reb"
            @entry[:readings] << txt
        elsif @curr_tag == "name_type"
            @entry[:name_type] << txt
        elsif @curr_tag == "trans_det"
            @entry[:translation] << txt
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
Usage: ruby jmnedict2.rb dicname

The xml content is passed by STDIN.
EOL
end

if $0 == __FILE__
    if ARGV.length != 1
        usage
    else
        $dictfmt = Dictfmt.new("#{ARGV[0]}.index", "#{ARGV[0]}.dict", false)

        $dictfmt.set_utf8
        $dictfmt.set_shortname(ARGV[0].capitalize)
        $dictfmt.set_info(
            "See http://www.csse.monash.edu.au/~jwb/enamdict_doc.html")

        parse($stdin)

        $dictfmt.dictzip
    end
end