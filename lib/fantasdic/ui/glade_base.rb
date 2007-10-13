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

# Code from Alexandria by Laurent Sansonetti

module Fantasdic
module UI
    class GladeBase
        def initialize(filename)
            file = File.join(Fantasdic::Config::DATA_DIR, 'glade', filename)
            text_domain = Fantasdic::TEXTDOMAIN
            glade = GladeXML.new(file,nil,text_domain) do |handler|
                method(handler)
            end
            glade.widget_names.each do |name|
                begin
                    instance_variable_set("@#{name}".intern, glade[name])
                rescue
                end
            end
        end
    end
end
end
