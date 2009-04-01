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
    COPYRIGHT = 'Copyright (C) 2006 - 2008 Mathieu Blondel'

    LIST = ''
    BUGZILLA = 'http://bugzilla.gnome.org/browse.cgi?product=fantasdic'
    BUGZILLA_REPORT_BUG = \
        'http://bugzilla.gnome.org/enter_bug.cgi?product=fantasdic'
    WEBSITE_URL = 'http://www.gnome.org/projects/fantasdic/'

    GPL = <<EOL
Fantasdic is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; either version 2 of the
License, or (at your option) any later version.

Fantasdic is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
EOL

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

    def self.missing_dependency(lib, msg=nil)
        @missing_deps ||= []
        @missing_deps << [lib, msg]
    end

    def self.display_missing_dependencies
        if @missing_deps
            $stderr.puts "-" * 60
            $stderr.puts "The following optional dependencies were not found."
            @missing_deps.each do |lib, msg|
                if msg
                    $stderr.puts("%s (%s)" % [lib, msg])
                else
                    $stderr.puts(lib)
                end
            end
            $stderr.puts "-" * 60
        end
    end
end

require 'fantasdic/gettext'

module Fantasdic
    TITLE = 'Fantasdic'
    TEXTDOMAIN = 'fantasdic'
    extend GetText
    bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")
    DESCRIPTION = _("Look up words in various dictionary sources")

    def self.main
        Source::Base::load_sources

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

        Fantasdic.display_missing_dependencies if HAVE_CONSOLE

        Fantasdic::UI.main
    end
end

require 'pp' if $DEBUG

require 'fantasdic/config'
require 'fantasdic/version'

require 'fantasdic/net/sockssocket'
require 'fantasdic/net/dict'

require 'fantasdic/text/porter_stemming'
require 'fantasdic/text/levenshtein'
require 'fantasdic/text/soundex'
require 'fantasdic/text/metaphone'
require 'fantasdic/text/double_metaphone'

require 'fantasdic/ui'

require 'fantasdic/preferences'
require 'fantasdic/command_line'
require 'fantasdic/utils'
require 'fantasdic/binary_search'
require 'fantasdic/dictzip'
require 'fantasdic/source_base'
require 'fantasdic/file_source'
