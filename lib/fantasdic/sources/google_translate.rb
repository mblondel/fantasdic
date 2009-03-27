# Fantasdic
# Copyright (C) 2006 - 2007 Mathieu Blondel
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

require "open-uri"
require "cgi"

module Fantasdic
module Source

    class GoogleTranslate < Base
        authors ["Mathieu Blondel"]
        title  _("Google Translate")
        description _("Translate words using Google Translate.")
        license Fantasdic::GPL
        copyright "Copyright (C) 2007 Mathieu Blondel"
        disable_search_all_databases true

        START_MARKUP = "<div id=[\"]?result_box[\"]? dir=[\"]?(ltr|rtl)[\"]?>"
        END_MARKUP = "</div>"
        URL = "http://translate.google.com/translate_t" + \
              "?ie=UTF8&langpair=%s&text=%s"

        LANGUAGES = \
           {"ar" => "Arabic",
            "bg" => "Bulgarian",
            "ca" => "Catalan",
            "zh-CN" => "Chinese",
            "hr" => "Croatian",
            "cs" => "Czech",
            "da" => "Danish",
            "nl" => "Dutch",
            "en" => "English",
            "et" => "Estonian",
            "tl" => "Filipino",
            "fi" => "Finnish",
            "fr" => "French",
            "gl" => "Galician",
            "de" => "German",
            "el" => "Greek",
            "iw" => "Hebrew",
            "hi" => "Hindi",
            "hu" => "Hungarian",
            "id" => "Indonesian",
            "it" => "Italian",
            "ja" => "Japanese",
            "ko" => "Korean",
            "lv" => "Latvian",
            "lt" => "Lithuanian",
            "mt" => "Maltese",
            "no" => "Norwegian",
            "pl" => "Polish",
            "pt" => "Portuguese",
            "ro" => "Romanian",
            "ru" => "Russian",
            "sr" => "Serbian",
            "sk" => "Slovak",
            "sl" => "Slovenian",
            "es" => "Spanish",
            "sv" => "Swedish",
            "th" => "Thai",
            "tr" => "Turkish",
            "uk" => "Ukrainian",
            "vi" => "Vietnamese"}

        def available_databases
            ret = {}
            LANGUAGES.each do |from_key, from_name|
                LANGUAGES.each do |to_key, to_name|
                    next if from_key == to_key
                    k = "%s|%s" % [from_key, to_key]
                    v = "%s to %s" % [from_name, to_name]
                    ret[k] = v
                end
            end
            ret
        end

        def available_strategies
            { "translate" => "Translate the words." }
        end

        def self.default_strategy
            "translate"
        end

        def define(db, word)
            db_escaped, word_escaped = CGI.escape(db), CGI.escape(word)
            begin               
                Kernel::open(URL % [db_escaped, word_escaped]) do |buffer|
                    case buffer.read
                        when /#{START_MARKUP}(.*)/
                            pos = $2.index(END_MARKUP)
                            if pos
                                res = $2[0..pos-1]
                                res = CGI.unescapeHTML(res)
                                res = convert_to_utf8(buffer.charset, res)
                                defi = Definition.new
                                defi.word = word
                                defi.database = db
                                defi.body = res
                                defi.description = available_databases[db]
                                [defi]
                            else
                                []
                            end
                        else
                            []
                    end
                end
            rescue SocketError, URI::InvalidURIError => e
                raise Source::SourceError, e.to_s
            end
        end
    end

end
end

Fantasdic::Source::Base.register_source(Fantasdic::Source::GoogleTranslate)
