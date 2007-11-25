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
module UI
    class AboutDialog < Gtk::AboutDialog
        include GetText
        GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

        set_url_hook do |about, url|
            Fantasdic::UI::Browser::open_url(url)
        end

        def initialize(parent)
            super()
            self.name = Fantasdic::TITLE
            self.version = Fantasdic::VERSION
            self.copyright = Fantasdic::COPYRIGHT
            self.comments = Fantasdic::DESCRIPTION
            self.authors = Fantasdic::AUTHORS
            self.documenters = Fantasdic::DOCUMENTERS

            # Display translators for relevant locale
            GLib.language_names.each do |l|
                if Fantasdic::TRANSLATORS[l]
                    self.translator_credits = \
                        Fantasdic::TRANSLATORS[l].join("\n")
                    break
                end
            end

            self.website = Fantasdic::WEBSITE_URL
            self.logo = Icon::LOGO_48X48
            self.license = Fantasdic::GPL
            self.transient_for = parent
            signal_connect('destroy') { hide }
            signal_connect('response') { destroy }
        end
    end
    
end
end
