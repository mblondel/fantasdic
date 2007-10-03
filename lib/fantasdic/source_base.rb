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
            def_field :author, :version, :title, :description, :cache
        end

        [Config::SOURCE_DIR, Config::PERSONAL_SOURCE_DIR].each do |dir|
            Dir["#{dir}/*.rb"].each { |f| load f }
        end

        def initialize(hash)
            @hash = hash
        end

        # Override this method in your class if you need a config widget
        def config_widget(parent_dialog, on_databases_changed_block)
            nil
        end

        def available_databases
            {}
        end

        def available_strategies
            []
        end

        def database_info(db)
            ""
        end

        def to_hash
            {}
        end
    end

end
end
