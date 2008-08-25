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

require 'singleton'
require 'yaml'

module Fantasdic

    module Config
    
        if WIN32
            CONFIG_DIR = File.join(ENV['USERPROFILE'],"fantasdic")
        else
            CONFIG_DIR = File.join(ENV['HOME'],".fantasdic")
        end

        CONFIG_FILE = File.join(CONFIG_DIR,"config.yaml")
        DEFAULT_CONFIG_FILE = File.join(DATA_DIR, "config", "default.yaml")
    end

    class PreferencesBase
    
        def initialize(config_file)
            @config_file = config_file

            @config = YAML.load(File.open(@config_file,
                                File::CREAT|File::RDWR))
            if @config and @config.is_a? Hash
                # merge with the default config in case of new parameters 
                dflt_config = YAML.load(File.open(Config::DEFAULT_CONFIG_FILE))
                dflt_config.each_key do |key|
                    if !@config.has_key? key
                        @config[key] = dflt_config[key]
                    end
                end
            else
                @config = YAML.load(File.open(Config::DEFAULT_CONFIG_FILE))
            end

            # copy the name of the dictionary in the dictionary info
            # so that it is available to the source object
            # when the config hash is passed            
            self.dictionaries_infos.each_key do |key|
                self.dictionaries_infos[key][:name] = key
            end
        end
        
        def save!
            File.open(@config_file,
                      File::CREAT|File::TRUNC|File::RDWR, 0600) do |f|
                YAML.dump(@config, f)
            end
        end

        # dictionaries_infos, a hash with:
        # :server, :port, :all_dbs, :sel_dbs, :avail_strats,
        # :sel_strat, :auth, :login, :password, :selected
        # dictionaries: an array of dictionary names (ordered)

        def update_dictionary(name, hash)
            self.dictionaries_infos[name] = hash
            self.dictionaries_infos[name][:name] = name
        end

        def add_dictionary(name, hash)
            update_dictionary(name, hash)
            self.dictionaries << name unless self.dictionaries.include? name
        end

        def delete_dictionary(name)
            return if not dictionary_exists?(name)
            self.dictionaries.delete(name)
            self.dictionaries_infos.delete(name)
        end

        def dictionary_up(name)
            return if not dictionary_exists?(name)
            new_index = self.dictionaries.index(name) + 1
            return if new_index == self.dictionaries.length
            self.dictionaries.delete(name)
            self.dictionaries.insert(new_index, name)
        end

        def dictionary_down(name)
            return if not dictionary_exists?(name)
            new_index = self.dictionaries.index(name) - 1
            return if new_index == -1
            self.dictionaries.delete(name)
            self.dictionaries.insert(new_index, name)
        end

        def dictionary_replace_name(old, new)
            return if not dictionary_exists?(old)
            index = self.dictionaries.index(old)
            self.dictionaries[index] = new
            self.dictionaries_infos[new] = self.dictionaries_infos[old]
            self.dictionaries_infos.delete(old)
        end

        def dictionary_exists?(dictionary)
            self.dictionaries.include? dictionary
        end
        
        def method_missing(id, *args)
            method = id.id2name
            if match = /(.*)=$/.match(method)
                if args.length != 1
                    raise "Set method #{method} should be called with " +
                          "only one argument (was called with #{args.length})"
                end
                @config[match[1]] = args.first
            else
                unless args.empty?
                    raise "Get method #{method} should be called " +
                          "without argument (was called with #{args.length})"
                end
                @config[method]
            end                
        end

    end

    class Preferences < PreferencesBase
        include Singleton

        def initialize
            unless(FileTest.exists?(Config::CONFIG_DIR))
                Dir.mkdir(Config::CONFIG_DIR)    
            end

            super(Config::CONFIG_FILE)
        end
    end

end
