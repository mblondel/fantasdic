# JMdict to dictd format converter
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

SENSE = {
    :gloss => "Translations",
    :stagk => "Kanji restriction",
    :stagr => "Reading restriction",
    :pos => "Part-of-speech",
    :xref => "Cross-reference",
    :ant => "Antonym",
    :field => "Field",
    :misc => "Miscellaneous",
    :s_inf => "Sense information",
    :example => "Example"
}

INFO = {
    :lang => "Originating language",
    :etym => "Etymology",
    :dial => "Dialect"
}

def add_entry(e)
    txt = ""
    kw = []

    # k_ele
    if e[:k_ele]
        txt += "[Kanji]\n\n"
    end

    e[:k_ele].each do |k_ele|
        if k_ele[:keb]
            txt += "#{k_ele[:keb]}\n"
            kw << k_ele[:keb]
        end
        txt += "(#{k_ele[:ke_inf].join(', ')})\n" if k_ele[:ke_inf]
    end if e[:k_ele]

    txt += "\n" if e[:k_ele]

    # r_ele
    if e[:r_ele]
        txt += "[Readings]\n\n"
    end

    e[:r_ele].each do |r_ele|
        if r_ele[:reb]
            txt += "#{r_ele[:reb]}"
            kw << r_ele[:reb]
        end
        txt += "(#{r_ele[:re_restr].join(', ')})" \
            if r_ele[:re_restr]

        txt += "\n" if r_ele[:reb]

        txt += "(#{r_ele[:re_inf].join(', ')})\n" if r_ele[:re_inf]
    end if e[:r_ele]

    txt += "\n" if e[:r_ele]

    # sense
    if e[:r_ele]
        txt += "[Sense]\n\n"
    end

    e[:sense].each do |sense|
        [:gloss, :stagk, :stagr, :pos, :xref, :ant, :field, :misc,
         :s_inf, :example].each do |s|
            if s == :gloss
                kw += sense[s] if sense[s]
                txt += "#{sense[s].join(', ')}\n" if sense[s]
            else
                txt += "#{SENSE[s]}: #{sense[s].join(', ')}\n" if sense[s]
            end            
        end
        txt += "\n"
    end if e[:sense]

    # info
    if e[:info]
        txt += "[Information]\n\n"
    end

    e[:info].each do |info|
        [:lang, :dial, :etym].each do |i|
            txt += "#{INFO[i]}: #{info[i].join(', ')}\n" if info[i]
        end
        txt += "\n"
    end if e[:info]    

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
        # k_ele
        elsif name == "k_ele"
            @entry[:k_ele] ||= []
            @entry[:k_ele] << {}
        elsif name == "ke_inf"
            @entry[:k_ele].last[:ke_inf] ||= []
        elsif name == "ke_pri"
            @entry[:k_ele].last[:ke_pri] ||= []
        # r_ele
        elsif name == "r_ele"
            @entry[:r_ele] ||= []
            @entry[:r_ele] << {}
        elsif name == "no_kanji"
            @entry[:r_ele].last[:no_kanji] = true
        elsif name == "re_restr"
            @entry[:r_ele].last[:re_restr] ||= []
        elsif name == "re_inf"
            @entry[:r_ele].last[:re_inf] ||= []
        elsif name == "re_pri"
            @entry[:r_ele].last[:re_pri] ||= []
        # info
        elsif name == "lang"
            @entry[:lang] ||= []
        elsif name == "dial"
            @entry[:dial] ||= []
        elsif name == "etym"
            @entry[:etym] ||= []
        # sense
        elsif name == "sense"
            @entry[:sense] ||= []
            @entry[:sense] << {}
        elsif ["stagk", "stagr", "pos", "xref", "ant", "field", "misc", "s_inf",
               "gloss", "example"].include? name
            @entry[:sense].last[name.to_sym] ||= []
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
        # k_ele
        if @curr_tag == "keb"
            @entry[:k_ele].last[:keb] ||= ""
            @entry[:k_ele].last[:keb] += txt
        elsif @curr_tag == "ke_inf"
            @entry[:k_ele].last[:ke_inf] << txt unless txt.empty?
        elsif @curr_tag == "ke_pri"
            @entry[:k_ele].last[:ke_pri] << txt unless txt.empty?
        # r_ele
        elsif @curr_tag == "reb"
            @entry[:r_ele].last[:reb] ||= ""
            @entry[:r_ele].last[:reb] += txt
        elsif @curr_tag == "re_restr"
            @entry[:r_ele].last[:re_restr] << txt unless txt.empty?
        elsif @curr_tag == "re_inf"
            @entry[:r_ele].last[:re_inf] << txt unless txt.empty?
        elsif @curr_tag == "re_pri"
            @entry[:r_ele].last[:re_pri] << txt unless txt.empty?
        # info
        elsif @curr_tag == "lang"
            @entry[:lang] << txt unless txt.empty?
        elsif @curr_tag == "dial"
            @entry[:dial] << txt unless txt.empty?
        elsif @curr_tag == "etym"
            @entry[:etym] << txt unless txt.empty?
        # sense
        elsif ["stagk", "stagr", "pos", "xref", "ant", "field", "misc", "s_inf",
               "gloss", "example"].include? @curr_tag
            @entry[:sense].last[@curr_tag.to_sym] << txt unless txt.empty?
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
Usage: ruby jmdict2dictd.rb dicname

The xml content is passed by STDIN.
EOL
end

if $0 == __FILE__
    if ARGV.length != 1
        usage
    else
        $dictfmt = Dictfmt.new("#{ARGV[0]}.index", "#{ARGV[0]}.dict", false)

        $dictfmt.set_utf8
        $dictfmt.set_shortname("JMdict")
        $dictfmt.set_info(
            "See http://www.csse.monash.edu.au/~jwb/edict_doc.html")

        parse($stdin)

        $dictfmt.dictzip
    end
end