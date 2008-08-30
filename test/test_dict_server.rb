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

$test_dir = File.expand_path(File.dirname(__FILE__))
$top_dir = File.expand_path(File.join($test_dir, ".."))
$lib_dir = File.expand_path(File.join($top_dir, "lib"))
$test_data_dir = File.expand_path(File.join($test_dir, "data"))
$LOAD_PATH.unshift($lib_dir)

require "test/unit"
require "fantasdic"
require "fantasdic/sources/dict_server"

class TestDictServerSource < Test::Unit::TestCase

    def setup
        config = {
            :server => "dict.org",
            :port => 2628,
            :auth => false,
            :login => "",
            :password => ""
        }
        @source = Fantasdic::Source::DictServer.new(config)
        @source.open
    end

    def teardown
        @source.close
    end

    def test_define
        defs = @source.define("eng-fra", "dictionary")
        assert_equal(defs.length, 1)
        assert_equal(defs.first.body.include?("dictionnaire"), true)
    end

    def test_prefix
        matches = @source.match("eng-fra", "prefix", "test")
        matches.each_value do |results|
            results.each do |word|
                assert_equal(word =~ /^test/, 0)
            end
        end
    end

end
