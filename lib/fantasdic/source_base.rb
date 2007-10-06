# Fantasdic
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

module Fantasdic

module Config
    SOURCE_DIR = File.join(LIB_DIR, "fantasdic/sources")
    PERSONAL_SOURCE_DIR = File.join(CONFIG_DIR, "sources")
    unless File.exist? PERSONAL_SOURCE_DIR
        Dir.mkdir PERSONAL_SOURCE_DIR
    end
end

module Source

    module Fields
        def def_field(*names)
            class_eval do
                names.each do |name|
                    define_method(name) do |*args|
                        case args.size
                            when 0: instance_variable_get("@#{name}")
                            else    instance_variable_set("@#{name}", *args)
                        end
                    end
                end
            end
        end
    end

    class SourceError < Exception; end

    class Base
        @registered_sources = []
        DEFAULT_SOURCE = "DictServer"
        ALL_DATABASES = DICTClient::ALL_DATABASES
        MAX_CACHE = 30

        class << self
            attr_reader :registered_sources

            def inherited(child)
                @registered_sources << child
            end

            def short_name
                self.name.split("::").last
            end

            def get_source(src)
                if src
                    @registered_sources.find { |s| s.short_name == src }
                else
                    @registered_sources.find do |s|
                        s.short_name == DEFAULT_SOURCE
                    end
                end
            end

            extend Fields
            def_field :authors, :version, :title, :description, :website,
                      :license, :copyright
        end

        def initialize(hash)
            @hash = hash
            @cache_queue = []
        end

        # Methods which should be implemented by children classes
        def available_databases
            {}
        end

        def available_strategies
            []
        end

        def database_info(db)
            ""
        end

        def define(db, word)

        end

        def match(db, strat, word)

        end

        # This class may be used to implement a config widget
        class ConfigWidget < Gtk::VBox
            def initialize(parent_dialog, hash, on_databases_changed_block)
                super()
                @parent_dialog
                @hash = hash
                @on_databases_changed_block = on_databases_changed_block
            end

            # Override this method if some fields need be saved in config file
            def to_hash
                {}
            end
        end

        # Methods below should not be overriden by children classes

        def multiple_define(dbs, word)
            definitions = []
            dbs.each do |db|
                definitions += define(db, word)
            end
            definitions
        end

        def cached_multiple_define(dbs, word)
            cache = Cache.new
            cache.key = [dbs, word]

            i = @cache_queue.index(cache)
            if i.nil?
                res = multiple_define(dbs, word)
                cache.value = res
                update_cache(cache)
                res
            else
                @cache_queue[i].value
            end
        end

        def multiple_match(dbs, strategy, word)
            matches = {}
            dbs.each do |db|
                m = match(db, strategy, word)
                m.each_key do |found_db|   
                    matches[found_db] = m[found_db]
                end
            end        
            matches
        end

        def cached_multiple_match(dbs, strategy, word)
            cache = Cache.new
            cache.key = [dbs, strategy, word]

            i = @cache_queue.index(cache)
            if i.nil?
                res = multiple_match(dbs, strategy, word)
                cache.value = res
                update_cache(cache)
                res
            else
                @cache_queue[i].value
            end
        end

        private

        class Cache < Struct.new(:key, :value)
            include Comparable

            def <=>(cache)
                self.key <=> cache.key
            end
        end

        def update_cache(cache)
            @cache_queue.unshift(cache)

            if @cache_queue.length > MAX_CACHE
                @cache_queue.pop
            end
        end

        # Load found source plugins (system-wide and user-wide)
        [Config::SOURCE_DIR, Config::PERSONAL_SOURCE_DIR].each do |dir|
            Dir["#{dir}/*.rb"].each { |f| load f }
        end

    end # class Base

end
end
