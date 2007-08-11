# FantasDic
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

require 'singleton'
require 'yaml'

module Fantasdic

    module Config
    
        if RUBY_PLATFORM =~ /win32/
            CONFIG_DIR = File.join(ENV['USERPROFILE'],"fantasdic")
        else
            CONFIG_DIR = File.join(ENV['HOME'],".fantasdic")
        end

        CONFIG_FILE = File.join(CONFIG_DIR,"config.yaml")
        DEFAULT_CONFIG_FILE = File.join(DATA_DIR, "config", "default.yaml")
    end

    class Preferences
        include Singleton
    
        def initialize
            unless(FileTest.exists?(Config::CONFIG_DIR))
                Dir.mkdir(Config::CONFIG_DIR)    
            end
            
            if(FileTest.exists?(Config::CONFIG_FILE))
                @config = YAML.load(File.open(Config::CONFIG_FILE))

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
        end
        
        def save!
            File.open(Config::CONFIG_FILE,
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
        end

        def add_dictionary(name, hash)
            update_dictionary(name, hash)
            self.dictionaries << name unless self.dictionaries.include? name
        end

        def delete_dictionary(name)
            self.dictionaries.delete(name)
            self.dictionaries_infos.delete(name)
        end

        def dictionary_up(name)
            new_index = self.dictionaries.index(name) + 1
            self.dictionaries.delete(name)
            self.dictionaries.insert(new_index, name)
        end

        def dictionary_down(name)
            new_index = self.dictionaries.index(name) - 1
            self.dictionaries.delete(name)
            self.dictionaries.insert(new_index, name)
        end

        def dictionary_replace_name(old, new)
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

        def get_browser
            # First try with gconf in order to get the default browser set in
            # System > Preferences > My favourite applications
            begin
                require "gconf2"
                client = GConf::Client.default
                dir = "/desktop/gnome/url-handlers/http/"
                if client[dir + "enabled"]
                    return client[dir + "command"]            
                end
            rescue LoadError 
            end

            # Second, see if user has not set a browser in the prefs file
            if self.www_browser
                return self.www_browser
            end

            # Third, try to find if one of those browsers is available
            ["firefox", "iceweasel", "mozilla", "epiphany", "konqueror",
             "w3m"].each do |browser|
                ENV["PATH"].split(":").each do |dir|
                    file = File.join(dir, browser)
                    if File.executable? file
                        return "#{file} %s"
                    end
                end
            end

            # Too bad...
            return nil
        end

        def open_url(command, url)
            Thread.new { system(command % url) }
        end

    end

end
