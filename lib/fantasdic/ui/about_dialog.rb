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
module UI
    class AboutDialog < Gtk::AboutDialog
        include GetText
        GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

        GPL = <<EOL
Fantasdic is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; either version 2 of the
License, or (at your option) any later version.

Fantasdic is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public
License along with Fantasdic; see the file COPYING.  If not,
write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
Boston, MA 02111-1307, USA.
EOL

        set_url_hook do |about, url|
            prefs = Preferences.instance
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

            GLib.language_names.each do |l|
                if Fantasdic::TRANSLATORS[l]
                    self.translator_credits = \
                        Fantasdic::TRANSLATORS[l].join("\n")
                    break
                end
            end

            self.website = Fantasdic::WEBSITE_URL
            self.logo = Icon::LOGO_48X48
            self.license = GPL
            self.transient_for = parent
            signal_connect('destroy') { hide }
            signal_connect('response') { destroy }
        end
    end
    
end
end
