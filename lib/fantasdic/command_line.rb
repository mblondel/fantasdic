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

require 'optparse'
require 'singleton'

module Fantasdic
    include GetText
    GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

class CommandLineOptions < Hash
    include Singleton
    include GetText
    GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

    def initialize
        begin
            @options = OptionParser.new do |opts|
                opts.banner = \
                    _("Usage: fantasdic [options] [dictionary] [word]")
    
                opts.on("-o", "--stdout", 
                        _("Print results to stdout")) do |b|
                    self[:stdout] = b
                end
    
                opts.on("-l", "--dict-list", 
                        _("List dictionaries in settings")) do |b|
                    self[:dict_list] = b
                end
    
                opts.on("-s", "--strat-list dictionary", String, 
                        _("List strategies available for dictionary")) do |dict|
                    self[:strat_list] = dict
                end
    
                opts.on("-m", "--match strategy", String, 
                        _("Use strategy to match words")) do |strat|
                    self[:match] = strat
                end

                opts.on_tail("-h", "--help", _("Show this message")) do
                    puts opts
                    exit!
                end
       
                opts.on_tail("-v", "--version", _("Show version")) do
                    puts "Fantasdic %s" % Fantasdic::VERSION
                    exit!
                end
    
            end

            @options.parse!
        rescue OptionParser::ParseError
            show_help!
        end
    end

    def show_help!
        puts @options.help
        exit!
    end
end

def self.connect(dict)
    prefs = Preferences.instance
    infos = prefs.dictionaries_infos[dict]

    if infos.nil?
        puts _("Error: Dictionary does not exist in the settings")
        return
    end

    begin
        source_class = Source::Base.get_source(infos[:source])
        source = source_class.new(infos)
    rescue Source::SourceError => e
        source = nil
        puts e.to_s
    end

    [source, infos]
end

def self.print_definitions(definitions)
    if definitions.empty?
        puts _("No match found.")
    else
        puts ngettext("One match found.", "Matches found: %d.",
                      definitions.length) % definitions.length
    end

    last_db = ""
    definitions.each do |d|
        if last_db != d.database
            puts "%s [%s]\n" % [d.description, d.database]
            last_db = d.database
        else
            puts "__________\n\n"
        end
        puts d.body
    end
end

def self.define(dict, word)
    dict, infos = connect(dict)
    return if dict.nil?

    begin
        dict.open

        if infos[:all_dbs] == true
            definitions = dict.define(DICTClient::ALL_DATABASES, word)
        else
            definitions = []
            infos[:sel_dbs].each do |db|
                definitions += dict.define(db, word)
            end
        end

        dict.close

        print_definitions(definitions)
    rescue Source::SourceError => e
        puts e.to_s
    end    
end

def self.print_matches(matches)
    if matches.length == 0
        puts _("No match found.")
        return
    end
        
    matches.each do |db, word|
        s = word.join(", ")
        puts "[%s]" % db
        puts s
        puts ""
    end
end

def self.match(dict, strat, word)
    dict, infos = connect(dict)
    return if dict.nil?

    begin
        dict.open

        if infos[:all_dbs] == true
            matches = dict.match(DICTClient::ALL_DATABASES, strat, word)
        else
            matches = {}
            infos[:sel_dbs].each do |db|
                m = dict.match(db, strat, word)
                matches[db] = m[db] unless m[db].nil?
            end
        end

        dict.close

        print_matches(matches)
    rescue Source::SourceError => e
        puts e.to_s
    end
end

def self.dict_list
    Preferences.instance.dictionaries_infos.each_key { |k| puts k }
end

def self.strat_list(dict)
    dict, infos = connect(dict)
    return if dict.nil?
    
    begin
        dict.open
        dict.available_strategies.each_key { |k| puts k }
        dict.close
    rescue Source::SourceError => e
        puts e.to_s
    end    
end

end