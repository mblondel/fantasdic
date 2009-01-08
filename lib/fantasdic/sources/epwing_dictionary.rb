# Fantasdic
# Copyright (C) 2009 Mathieu Blondel
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

begin
    require "eb"
    require "base64"
rescue LoadError
end

module Fantasdic
module Source

class EpwingDictionary < Base

    authors ["Mathieu Blondel"]
    title  _("EPWING dictionary")
    description _("Look up words in EPWING dictionaries.")
    license Fantasdic::GPL
    copyright "Copyright (C) 2009 Mathieu Blondel"

    class ConfigWidget < FileSource::ConfigWidget

        def initialize(*args)
            super(*args)

            @choose_file_message = _("Select a CATALOGS file")
            @file_extensions = [["CATALOGS", "CATALOGS"]]
            @encodings = []

            initialize_ui
            initialize_data
            initialize_signals
        end

    end

    def initialize(*args)
        super(*args)
        if not Object.const_defined? "EB"
            raise Source::SourceError,
                 _("You're missing rubyeb (libeb for Ruby)!")
        end
    end

    def check_validity
        book_open { |book| nil } # just try to open the book
    end

    def available_databases
        ret = {}
        book_open do |book|
            subbook_list(book).each do |title|
                ret[title] = title
            end
        end
        ret
    end

    def available_strategies
        { "define" => "Results match with the word exactly.",
          "prefix" => "Results match with the beginning of the word." }
    end

    def define(db, word)
        word = convert_utf8_to("euc-jp", word)

        book_open do |book|
            subbooks = if db == Source::Base::ALL_DATABASES
                book.subbook_list
            else
                [subbook_name_to_id(book, db)]
            end

            subbooks.map do |i|
                name = subbook_id_to_name(book, i)
                book.subbook = i

                if self.class.position_cache.has_key? [name, word]
                    # use the position cache if available
                    items = get_definitions(book, word,
                                self.class.position_cache[[name,word]])
                else
                    # or search if not...
                    items = book.exactsearch(word)
                end

                items.map do |head, contents|
                    defi = Definition.new
                    defi.word = convert_to_utf8("euc-jp", head)
                    defi.body = convert_to_utf8("euc-jp", contents)
                    defi.database = name
                    defi.description = name.capitalize
                    defi
                end
            end.sum
        end
    end

    def match(db, strat, word)
        case strat
            when "prefix"
                match_with_func(db, strat, word, :search2)
            else
                []
        end
    end

    # This is a dirty hack to retain the position of the previous search!
    def self.position_cache
        @position_cache ||= {}
    end

    private

    def get_definitions(book, head, positions)
        positions.map { |pos| [head, book.content(pos)] }
    end

    def match_with_func(db, strat, word, func)
        word = convert_utf8_to("euc-jp", word)

        hsh = {}
        self.class.position_cache.clear

        book_open do |book|
            subbooks = if db == Source::Base::ALL_DATABASES
                book.subbook_list
            else
                [subbook_name_to_id(book, db)]
            end

            subbooks.each do |i| 
                book.subbook = i
                items = book.method(func).call(word)
                name = subbook_id_to_name(book, i)
                
                hsh[name] = items.map do |pos, head|
                    self.class.position_cache[[name, head]] ||= []
                    self.class.position_cache[[name, head]] << pos
                    convert_to_utf8("euc-jp", head)
                end
            end
        end

        hsh
    end

    def book_open
        book = EB::Book.new
        begin
            book.bind(File.dirname(@config[:filename]))
        rescue RuntimeError
            raise Source::SourceError, _("Not an EPWING dictionary!")
        end
        book.hookset = create_hookset
        yield book
    end

    def subbook_name_to_id(book, name)
        0.upto(book.subbook_count-1) do |i|
            title = convert_to_utf8("euc-jp", book.title(i))
            return i if title == name
        end
        nil
    end

    def subbook_id_to_name(book, id)
        convert_to_utf8("euc-jp", book.title(id))
    end

    def subbook_list(book)
        (0..book.subbook_count-1).to_a.map do |i|
            subbook_id_to_name(book, i)
        end
    end

    def get_narrow_font_size(height)
        # height can be 16, 24, 30, 48
        [height / 2, height, EB.const_get("FONT_#{height.to_s}")]
    end

    def get_wide_font_size(height)
        [height, height, EB.const_get("FONT_#{height.to_s}")]
    end

    def create_hookset
        h = EB::Hookset.new

        h.register(EB::HOOK_NEWLINE) do |eb, argv|
            "\n"
        end

        h.register(EB::HOOK_WIDE_FONT) do |eb, argv|
            code = argv[0]
            w, h, fontcode = get_wide_font_size(16)
            eb.fontcode = fontcode
            raw = eb.get_widefont(code).to_bmp
            b64 = Base64.encode64(raw).gsub("\n", "")            
            "[img b64=\"#{b64}\" /]"
        end

        h.register(EB::HOOK_NARROW_FONT) do |eb, argv|
            code = argv[0]
            w, h, fontcode = get_narrow_font_size(16)
            eb.fontcode = fontcode
            raw = eb.get_narrowfont(code).to_bmp
            b64 = Base64.encode64(raw).gsub("\n", "")  
            "[img b64=\"#{b64}\" /]"
        end

        h.register(EB::HOOK_BEGIN_EMPHASIS) do |eb, argv|
            "<b>"
        end

        h.register(EB::HOOK_END_EMPHASIS) do |eb, argv|
            "</b>"
        end

        h.register(EB::HOOK_BEGIN_SUBSCRIPT) do |eb, argv|
            "<sub>"
        end

        h.register(EB::HOOK_END_SUBSCRIPT) do |eb, argv|
            "</sub>"
        end

        h.register(EB::HOOK_BEGIN_SUPERSCRIPT) do |eb, argv|
            "<sup>"
        end

        h.register(EB::HOOK_END_SUPERSCRIPT) do |eb, argv|
            "</sup>"
        end

        h.register(EB::HOOK_BEGIN_REFERENCE) do |eb, argv|
            "{"
        end

        h.register(EB::HOOK_END_REFERENCE) do |eb, argv|
            "}"
        end

        h.register(EB::HOOK_BEGIN_CANDIDATE) do |eb, argv|
            "<i>"
        end

        h.register(EB::HOOK_END_CANDIDATE_GROUP) do |eb, argv|
            "</i>"
        end

        h.register(EB::HOOK_BEGIN_MONO_GRAPHIC) do |eb, argv|
            ""
        end

        h.register(EB::HOOK_END_MONO_GRAPHIC) do |eb, argv|
            ""
        end

        h.register(EB::HOOK_BEGIN_COLOR_BMP) do |eb, argv|
            ""
        end

        h.register(EB::HOOK_BEGIN_COLOR_JPEG) do |eb, argv|
            ""
        end

        h.register(EB::HOOK_END_COLOR_GRAPHIC) do |eb, argv|
            ""
        end

        img_hook = Proc.new do |eb, argv|
            eb.read_colorgraphic(EB::Position.new(argv[2], argv[3])) do |raw|
                b64 = Base64.encode64(raw).gsub("\n", "")  
                "[img b64=\"#{b64}\" /]"
            end
        end

        h.register(EB::HOOK_BEGIN_IN_COLOR_BMP, &img_hook) \
            if EB.const_defined?(:HOOK_BEGIN_IN_COLOR_BMP)

        h.register(EB::HOOK_BEGIN_IN_COLOR_JPEG, &img_hook) \
            if EB.const_defined?(:HOOK_BEGIN_IN_COLOR_JPEG)

        h.register(EB::HOOK_BEGIN_WAVE) do |eb, argv|
            "(wave file ignored)"
        end

        h.register(EB::HOOK_END_WAVE) do |eb, argv|
            ""
        end

        h.register(EB::HOOK_BEGIN_MPEG) do |eb, argv|
            "(mpeg file ignored)"
        end

        h.register(EB::HOOK_END_MPEG) do |eb2,argv|
            ""
        end

        h
    end

end

end
end

Fantasdic::Source::Base.register_source(Fantasdic::Source::EpwingDictionary)

