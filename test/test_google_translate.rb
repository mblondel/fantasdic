# Fantasdic
# Copyright (C) 2008 Mathieu Blondel
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

test_dir = File.expand_path(File.dirname(__FILE__))
top_dir = File.expand_path(File.join(test_dir, ".."))
lib_dir = File.expand_path(File.join(top_dir, "lib"))
$LOAD_PATH.unshift(lib_dir)

require "test/unit"
require "fantasdic"
require "fantasdic/sources/google_translate"

class TestGoogleTranslateSource < Test::Unit::TestCase

    def setup
        @source = Fantasdic::Source::GoogleTranslate.new({})
    end

    def test_define
        defs = @source.define("fr|en", "Salut")
        assert_equal(1, defs.length)
        assert_equal("Hi", defs[0].body)
    end

end
