# Fantasdic
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

module Fantasdic

    TITLE = 'Fantasdic'
    TEXTDOMAIN = 'fantasdic'
    extend GetText
    bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")
    DESCRIPTION = _('A client for the DICT protocol.')
    COPYRIGHT = 'Copyright (C) 2006 Mathieu Blondel'
    AUTHORS = [
        'Mathieu Blondel <mblondel@cvs.gnome.org>',
        'John Spray <spray@lyx.org>'
    ]
    DOCUMENTERS = [

    ]
    TRANSLATORS = [
        'Mathieu Blondel <mblondel@cvs.gnome.org> (French)',
        'Jérémy Ar Floc\'h <jeremy.lefloch@gmail.com> (Breton)',
        'Hendrik Brandt <heb@gnome-de.org> (German)',
        'Raphael Higino <raphaelh@uai.com.br> (Brazilian Portuguese)',
        'Danilo Šegan <danilo@gnome.org> (Serbian)',
        'Daniel Nylander <po@danielnylander.se> (Swedish)',
        'Emilio Anzon <pan@linux.it> (Italian)'
    ]

    LIST = ''
    BUGZILLA = 'http://bugzilla.gnome.org/ (product fantasdic)'
    WEBSITE_URL = 'http://www.gnome.org/projects/fantasdic/'

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
require 'fantasdic/dict'
require 'fantasdic/utils'
require 'fantasdic/command_line'
require 'fantasdic/ui'