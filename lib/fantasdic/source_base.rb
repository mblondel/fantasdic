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

module Fantasdic

module Config
    SOURCE_DIR = File.join(LIB_DIR, "fantasdic/sources")
    PERSONAL_SOURCE_DIR = File.join(CONFIG_DIR, "sources")
    unless File.exist? PERSONAL_SOURCE_DIR
        require "fileutils"
        FileUtils.mkdir_p PERSONAL_SOURCE_DIR
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
        include GetText
        GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

        @registered_sources = []
        
        DEFAULT_SOURCE = "DictServer"
        ALL_DATABASES = DICTClient::ALL_DATABASES
        MAX_CACHE = 30

        class << self
            attr_reader :registered_sources

            def register_source(source)
                @registered_sources << source
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

            def cache_queue
                @cache_queue ||= []
            end

            include GetText
            GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

            extend Fields
            def_field :authors, :version, :title, :description, :website,
                      :license, :copyright

            def_field :disable_search_all_databases, :no_databases
        end

        def initialize(config={})
            @config = config
            @max_cache = config[:max_cache] ? config[:max_cache] : MAX_CACHE
        end

        # Methods which should be implemented by children classes

        # Mostly useful for opening/closing IO streams.
        def open

        end

        def close

        end

        # Returns a hash with available databases. Keys are databases short
        # names and values are databases long names.
        def available_databases
            {}
        end

        # Returns a hash with available strategies. Keys are strategies short
        # names and values are strategies long names.
        def available_strategies
            {}
        end

        # Returns the string of the default strategy.
        def self.default_strategy
            "define"
        end

        # Returns a string with information regarding database db.
        def database_info(db)
            ""
        end

        # Definition object.
        #   - word: the word the definition is for.
        #   - body: the definition's body.
        #   - database: the database the definiton belongs to.
        #   - description: the database long name.
        class Definition < Struct.new(:word, :body, :database, :description)
        end

        # Returns an array of Definition objects.
        def define(db, word)
            []
        end

        # Returns a hash of matches grouped by database.
        # Keys are databases short names. Values are arrays of matches.
        # E.g:
        # {
        # "db1" => ["match1", "match2"],
        # "db2" => ["match3", "match4"]
        # }
        def match(db, strat, word)
            {}
        end

        # This class may be inherited in order to implement a config widget.
        class ConfigWidget < Gtk::VBox
            include GetText
            GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

            def initialize(parent_dialog, config, on_databases_changed_block)
                super()
                @parent_dialog
                @config = config
                @on_databases_changed_block = on_databases_changed_block
                self.spacing = 15
            end

            # Override this method if some fields need be saved in config file.
            def to_hash
                {}
            end
        end

        # Defines a word in an array of databases.
        # It may be useful to overridde this method
        # for cases when calling "define" several times is not efficient.
        def multiple_define(dbs, word)
            definitions = []
            dbs.each do |db|
                definitions += define(db, word)
            end
            definitions
        end

        # Same as above
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

        def connecting_to_source_str
            _("Connecting to source...")
        end

        def transferring_data_str
            _("Transferring data from source ...")
        end

        # Methods below should not be overridden by children classes

        def cached_multiple_define(dbs, word)
            cache = Cache.new
            cache.key = [@config.object_id, dbs, word]

            i = self.class.cache_queue.index(cache)
            if i.nil?
                res = multiple_define(dbs, word)
                cache.value = res
                update_cache(cache)
                res
            else
                self.class.cache_queue[i].value
            end
        end

        def cached_multiple_match(dbs, strategy, word)
            cache = Cache.new
            cache.key = [@config.object_id, dbs, strategy, word]

            i = self.class.cache_queue.index(cache)
            if i.nil?
                res = multiple_match(dbs, strategy, word)
                cache.value = res
                update_cache(cache)
                res
            else
                self.class.cache_queue[i].value
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
            self.class.cache_queue.unshift(cache)

            if self.class.cache_queue.length > @max_cache
                self.class.cache_queue.pop
            end
        end

        def convert_to_utf8(src_enc, str)
            begin 
                Iconv.new("utf-8", src_enc).iconv(str)
            rescue Iconv::IllegalSequence
                raise Source::SourceError, _("Can't convert encodings.")
            end
        end

        def convert_utf8_to(dest_enc, str)
            begin 
                Iconv.new(dest_enc, "utf-8").iconv(str)
            rescue Iconv::IllegalSequence
                raise Source::SourceError, _("Can't convert encodings.")
            end
        end

        def self.load_sources
            # Load found source plugins (system-wide and user-wide)
            [Config::SOURCE_DIR, Config::PERSONAL_SOURCE_DIR].each do |dir|
                Dir["#{dir}/*.rb"].each { |f| load f }
            end
        end

    end # class Base

end
end
