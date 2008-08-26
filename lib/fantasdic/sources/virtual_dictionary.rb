# Fantasdic
# Copyright (C) 2008 Mathieu Blondel
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

module Fantasdic
module Source

class VirtualDictionaryBase < Base

    STRATEGIES_DESC = {
        "define" => "Results match with the word exactly.",
        "prefix" => "Results match with the beginning of the word.",
        "word" => "Results have one word that match with the word.",
        "substring" => "Results have a portion that contains the word.",
        "suffix" => "Results match with the end of the word."
    }

    def initialize(prefs, *args)
        super(*args)
        @prefs = prefs
    end

    def available_strategies
        STRATEGIES_DESC
    end

    def available_databases
        hsh = {}
        authorized_databses.each { |d| hsh[d] = d }
        hsh
    end

    def define(db, word)
        virtual_dbs = if db == Source::Base::ALL_DATABASES
            authorized_databses
        else
            [db]
        end

        virtual_dbs.map do |db|
            src_class, config, dbs = get_source(db)
            src = src_class.new(config)
            src.open
            definitions = src.cached_multiple_define(dbs, word)
            src.close
            definitions
        end.sum
    end

    def match(db, strat, word)
        dbs = if db == Source::Base::ALL_DATABASES
            authorized_databses
        else
            [db]
        end

        matches = {}
        dbs.each do |db|
            src_class, config, dbs = get_source(db)
            src = src_class.new(config)
            src.open
            m = src.cached_multiple_match(dbs, strat, word)
            m.each_key do |found_db|
                matches[found_db] ||= []
                matches[found_db] += m[found_db]
            end
            src.close
        end

        matches
    end

    private

    def is_virtual?(db)
        @prefs.dictionaries_infos[db][:source] == "VirtualDictionary"
    end

    def authorized_databses
        @prefs.dictionaries.find_all { |db| not is_virtual?(db) }
    end

    def get_source(db)
        config = @prefs.dictionaries_infos[db]

        unless config
            raise SourceError,
                  _("Dictionary \"%s\" does not exist anymore") % \
                    db
        end

        dbs = if config[:all_dbs]
            [Source::Base::ALL_DATABASES]
        else
            config[:sel_dbs]
        end
        src_class = Fantasdic::Source::Base.get_source(config[:source])
        [src_class, config, dbs]
    end

end

class VirtualDictionary < VirtualDictionaryBase

    authors ["Mathieu Blondel"]
    title  _("Virtual dictionary")
    description _("Look up words in several dictionaries at once.")
    license Fantasdic::GPL
    copyright "Copyright (C) 2008 Mathieu Blondel" 

    def initialize(*args)
        super(Preferences.instance, *args)
    end

end

end
end

Fantasdic::Source::Base.register_source(Fantasdic::Source::VirtualDictionary)
