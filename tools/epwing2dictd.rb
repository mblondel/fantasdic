# EPWING to dictd format converter
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

$KCODE = "u"

require "eb"
require "iconv"
require "md5"

begin
    require './gaiji'
rescue LoadError
    # Define those two hashes in a file called gaiji.rb if your dictionary
    # has gaiji. Keys are gaiji code and values are the associated character
    # in utf-8.
    $narrow = {}
    $wide = {}
end

=begin
# Here's an example.

$narrow = {
    41281 => "À",
    41283 => "Â",
    41288 => "Ç",
    41289 => "È",
    41290 => "É",
    41291 => "Ê",
    41295 => "Ô",
    41313 => "à",
    41314 => "á",
    41315 => "â",
    41316 => "ã",
    41319 => "æ",
    41320 => "ç",
    41321 => "è",
    41322 => "é",
    41323 => "ê",
    41324 => "ë",
    41326 => "í",
    41327 => "î",
    41328 => "ï",
    41330 => "ñ",
    41333 => "ô",
    41335 => "ö",
    41337 => "ø",
    41338 => "ù",
    41340 => "û",
    41341 => "ü",
    41582 => "ŋ",
    41589 => "Œ",
    41590 => "œ",
    41808 => "ɔ",
    41811 => "ə",
    41818 => "ɑ",
    41821 => "ʃ",
    41824 => "ʒ",
    41826 => "ɛ",
    41827 => "ɡ",
    41828 => "ã",
    41829 => "~ɔ",
    
}

$wide = {
    42017 => "(",
    42018 => ")",
    42059 => "*",
    42060 => "**",
    42061 => "***",
    42062 => "<=",
    42067 => "€",
    42070 => "→",
    42087 => "n",
    42088 => "~ɛ",
    42089 => "~œ",
    42092 => "ɥ",
    42093 =>  "•",
    42095 => "(",
    42096 => ")",
    42097 => "(",
    42098 => ")"
    
}

# Add gaiji such as ① from 1 to 34
diff = 42023 - 1
(42023..42056).to_a.each do |code|
    $wide[code] = "\n(" + (code - diff).to_s + ")"
end
=end

class String
    def to_utf8
        begin 
            Iconv.new("utf-8", "euc-jp").iconv(self)
        rescue Iconv::IllegalSequence
            ""
        end
    end

    def to_euc_jp
        Iconv.new("euc-jp", "utf-8").iconv(self)
    end

    def utf8_length
        self.unpack("U*").length
    end
end

class EB::Book
    def gaiji_w(code)
        self.fontcode = EB::FONT_16
        self.get_widefont(code).to_bmp
    end

    def gaiji_n(code)
        self.fontcode = EB::FONT_16
        self.get_narrowfont(code).to_bmp
    end
end

class IndexExtractor

    def initialize(dir, subbook)
        book = EB::Book.new
        book.bind(dir)        
        book.subbook = subbook.to_i
       
        book.search("") do |heading, text|
            puts heading.to_utf8
        end
    end

end

class GaijiExtractor

    def initialize(dir, subbook)
        book = EB::Book.new
        book.bind(dir)        
        book.subbook = subbook.to_i
        
        h = EB::Hookset.new
        
        h.register(EB::HOOK_NARROW_FONT) do |eb2,argv|
            code = argv[0]
            bmp = book.gaiji_n(code)
            file = "narrow_" + code.to_s + ".bmp"    
            File.new(file, File::CREAT|File::RDWR).write(bmp) \
                unless FileTest.exist? file
            "<?>"
        end
        
        h.register(EB::HOOK_WIDE_FONT) do |eb2,argv|
            code = argv[0]
            bmp = book.gaiji_w(code)
            file = "wide_" + code.to_s + ".bmp"    
            File.new(file, File::CREAT|File::RDWR).write(bmp) \
                unless FileTest.exist? file
            "<?>"
        end
        
        book.hookset = h

        book.search("") do
        end

    end

end

class Converter

    def puts_definition(headword, definition)   
        puts "_____\n\n#{headword}"
        puts " "       
        puts definition
        puts ""
    end

    def initialize(dir, subbook, check_uniqueness=false)
        @check_uniqueness = check_uniqueness
        book = EB::Book.new
        book.bind(dir)

        book.subbook = subbook.to_i

        h = EB::Hookset.new

        h.register(EB::HOOK_NARROW_FONT) do |eb2,argv|
            code = argv[0]
        "<gaiji_n:%d>" % code
        end
        
        h.register(EB::HOOK_WIDE_FONT) do |eb2,argv|
            code = argv[0]
            "<gaiji_w:%d>" % code
        end

        # By convention, the link syntax is {link}
        h.register(EB::HOOK_BEGIN_REFERENCE) do
            "{"
        end
        
        h.register(EB::HOOK_END_REFERENCE) do
            "}"
        end

        book.hookset = h
        
        checksums = {}
        

        book.search("") do |heading, text|
            heading = heading.to_utf8
            text = text.to_utf8
    
            text.scan(/<gaiji_(n|w):(\d+)>/).each do |type, code|
                code = code.to_i
                if type == "n"
                    next unless $narrow.include? code
                    text.gsub!("<gaiji_n:%d>" % code, $narrow[code])
                elsif type == "w"
                    next unless $wide.include? code
                    text.gsub!("<gaiji_w:%d>" % code, $wide[code])
                end
            end
            
            if @check_uniqueness
                checksum = MD5::new(text).hexdigest          
                checksums[heading] ||= []
    
                unless checksums[heading].include? checksum
                    checksums[heading] << checksum
                    puts_definition(heading, text)
                end
            else
                puts_definition(heading, text)
            end
        end
       

    end

end

class CrownFRConverter < Converter

    def puts_definition(headword, definition)   
        headword.gsub!(/^(━━)/, "")
        headword.gsub!(/(\,)$/, "")
        headword.gsub!(/(\(\w+\))$/, "")
        headword.gsub!(/([0-9]+)$/, "")

        puts "_____\n\n#{headword}"
        puts " "       
        puts definition
        puts ""
    end

end

class ConcJFConverter < Converter

    def initialize(dir, subbook)
        super(dir, subbook, true)
    end   
    
    def get_alt(word)
        word = word.dup
        s = word.scan(/(.{1})\((.*)\)/)
        
        if s.empty?
            [word, nil]
        else
            alt_word = word.dup
            s.each do |char, alt_chars|
                alt_word.gsub!(char, alt_chars)
                alt_word.gsub!("(%s)" % alt_chars, "")
                word.gsub!("(%s)" % alt_chars, "")
            end
            [word, alt_word]
        end
    end

    def puts_definition(headword, definition)   
        headword.split(" ").each do |w|
            get_alt(w).each do |word|           
                unless word.nil?
                    puts "_____\n\n#{word}"
                    puts " "       
                    puts definition
                    puts ""
                end
            end            
        end
    end
end

class EijiroConverter < Converter

    def puts_definition(headword, definition)   
        headword.gsub!(/^(\~\ |__% |__ |__\-)/, "")
        #headword = headword.split(" ").first

        puts "_____\n\n#{headword}"
        puts " "       
        puts definition
        puts ""
    end

end

def usage
puts <<EOL
Usage

1) ruby epwing2dictd.rb index dictionary_dir subbook_num

    Extract the dictionary's index

2) ruby epwing2dictd.rb gaiji dictionary_dir subbook_num

    Extract gaiji in use in subbook as .bmp files.
    You can then edit a gaiji.rb file with gaiji code
    to utf8 character mapping.

3) ruby epwing2dictd.rb convert dictionary_dir subbook_num

    Convert to dictd format. Should be piped to :
        dictfmt -c5 --utf8 -s "Long name" "shortname"

    Can be used with any epwing dictionary.

4) ruby epwing2dictd.rb crownfr dictionary_dir subbook_num

    Same as convert but do some special processing for Sanseido's CrownFR.

5) ruby epwing2dictd.rb concisjf dictionary_dir subbook_num

    Same as convert but do some special processing for Sanseido's ConcisJF.

6) ruby epwing2dictd.rb eijiro dictionary_dir subbook_num

    Same as convert but do some special processing for Eijiro.

Note

This tool uses rubyeb, the Ruby bindings for libeb.

The default behavior of libeb prevents from looking up empty strings.
However, this tool needs to do it.

In libeb's setword.c, comment out the if statements that return
EB_ERR_EMPTY_WORD. Then recompile the library and reinstall it.

You may have to use LD_LIBRARY_PATH=/usr/local/lib/ as a prefix to run it.

EOL

end

if ARGV.length != 3
    usage
else
    if ARGV[0] == "index"
        IndexExtractor.new(ARGV[1], ARGV[2])
    elsif ARGV[0] == "gaiji"
        GaijiExtractor.new(ARGV[1], ARGV[2])
    elsif ARGV[0] == "convert"
        Converter.new(ARGV[1], ARGV[2])
    elsif ARGV[0] == "crownfr"
        CrownFRConverter.new(ARGV[1], ARGV[2])
    elsif ARGV[0] == "concjf"
        ConcJFConverter.new(ARGV[1], ARGV[2])
    elsif ARGV[0] == "eijiro"
        EijiroConverter.new(ARGV[1], ARGV[2])
    else 
        usage
    end
end
    