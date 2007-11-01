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
        license UI::AboutDialog::GPL
        copyright "Copyright (C) 2007 Mathieu Blondel"
        disable_search_all_databases true

        START_MARKUP = "<div id=result_box dir=ltr>"
        END_MARKUP = "</div>"
        URL = "http://translate.google.com/translate_t" + \
              "?ie=UTF8&langpair=%s&text=%s"

        def available_databases
            {
                "ar|en" => "Arabic to English",
                "zh|en" => "Chinese to English",
                "zh-CN|zh-TW" => "Chinese (Simplified to Traditional)",
                "zh-TW|zh-CN" => "Chinese (Traditional to Simplified)",
                "en|ar" => "English to Arabic",
                "en|zh-CN" => "English to Chinese (Simplified)",
                "en|zh-TW" => "English to Chinese (Traditional)",
                "en|fr" => "English to French",
                "en|de" => "English to German",
                "en|it" => "English to Italian",
                "en|ja" => "English to Japanese",
                "en|ko" => "English to Korean",
                "en|pt" => "English to Portuguese",
                "en|ru" => "English to Russian",
                "en|es" => "English to Spanish",
                "fr|en" => "French to English",
                "fr|de" => "French to German",
                "de|en" => "German to English",
                "de|fr" => "German to French",
                "it|en" => "Italian to English",
                "ja|en" => "Japanese to English",
                "ko|en" => "Korean to English",
                "pt|en" => "Portuguese to English",
                "ru|en" => "Russian to English",
                "es|en" => "Spanish to English"
            }
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
                            pos = $1.index(END_MARKUP)                        
                            if pos
                                res = $1[0..pos-1]
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