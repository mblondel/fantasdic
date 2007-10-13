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

begin
    require 'fantasdic/authors'
rescue LoadError
    module Fantasdic
        AUTHORS = ['Mathieu Blondel <mblondel@svn.gnome.org>']
    end
end

begin
    require 'fantasdic/translators'
rescue LoadError
    module Fantasdic
        TRANSLATORS = {}
    end
end

begin
    require 'fantasdic/documenters'
rescue LoadError
    module Fantasdic
        DOCUMENTERS = ['Mathieu Blondel <mblondel@svn.gnome.org>']
    end
end

module Fantasdic
    COPYRIGHT = 'Copyright (C) 2006 - 2007 Mathieu Blondel'

    LIST = ''
    BUGZILLA = 'http://bugzilla.gnome.org/browse.cgi?product=fantasdic'
    BUGZILLA_REPORT_BUG = \
        'http://bugzilla.gnome.org/enter_bug.cgi?product=fantasdic'
    WEBSITE_URL = 'http://www.gnome.org/projects/fantasdic/'

    WIN32 = (/mingw|mswin|win32/ =~ RUBY_PLATFORM)

    if WIN32
        begin
            open("CONIN$") {}
            open("CONOUT$", "w") {}
            HAVE_CONSOLE = true
        rescue SystemCallError
            HAVE_CONSOLE = false
        end
    else
        HAVE_CONSOLE = true
    end 
end

begin
    require 'gettext'
rescue LoadError
    require 'fantasdic/gettext'
    if Fantasdic::HAVE_CONSOLE
        $stderr.puts 'WARNING : Ruby/Gettext was not found.'
        $stderr.puts 'The interface will therefore remain in English.'
    end
end

module Fantasdic
    TITLE = 'Fantasdic'
    TEXTDOMAIN = 'fantasdic'
    extend GetText
    bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")
    DESCRIPTION = _("Dictionary application (DICT client).")

    def self.main
        options = CommandLineOptions.instance

        if ARGV.length == 1 or ARGV.length > 2
            options.show_help!
        elsif options[:dict_list]
            dict_list
            exit!
        elsif options[:strat_list]
            strat_list(options[:strat_list])
            exit!
        elsif ARGV.length == 2 and options[:stdout]
            if options[:match]
                match(ARGV[0], options[:match], ARGV[1])
            else
                define(ARGV[0], ARGV[1])
            end
            exit!
        end

        Fantasdic::UI.main
    end
end

require 'pp' if $DEBUG

require 'fantasdic/config'
require 'fantasdic/version'
require 'fantasdic/preferences'
require 'fantasdic/net/sockssocket'
require 'fantasdic/net/dict'
require 'fantasdic/utils'
require 'fantasdic/command_line'
require 'fantasdic/ui'
require 'fantasdic/source_base'