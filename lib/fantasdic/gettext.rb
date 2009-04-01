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
    require 'gettext'
rescue LoadError
    Fantasdic.missing_dependency('Ruby/Gettext', 
                                 'Internationalization support')

    module GetText
        module_function

        def _(str)
            str
        end

        def ngettext(str1, str2, n=nil)
            str2
        end

        def bindtextdomain(domainname, path = nil, locale = nil, charset = nil)
        end
    end

end