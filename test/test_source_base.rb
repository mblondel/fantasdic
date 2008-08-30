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

class TestSourceBase < Test::Unit::TestCase

    class MySource < Fantasdic::Source::Base

        attr_reader :n_define_calls, :n_match_calls

        def initialize(*args)
            super(*args)

            @n_define_calls = 0
            @n_match_calls = 0
        end

        def define(db, number)
            # Return number ^ 2
            definition = Fantasdic::Source::Base::Definition.new
            definition.word = number
            definition.body = (number.to_i ** 2).to_s
            definition.database = "db"
            definition.description = "Database"

            @n_define_calls += 1

            [definition]
        end

        def match(db, strat, number)
            @n_match_calls += 1
            {"db1" => [(number.to_i ** 2).to_s]}
        end

    end

    def setup
        @source = MySource.new({:max_cache => 3})
    end

    def test_define
        defs = @source.define("*", "2")
        assert_equal(defs.length, 1)
        assert_equal(defs.first.body, "4")
    end

    def test_define_number(number, result)
        defs = @source.cached_multiple_define(["db1"], number)
        assert_equal(defs.length, 1)
        assert_equal(defs.first.body, result)
    end
    private :test_define_number

    def test_cached_multiple_define
        test_define_number("2", "4")
        assert_equal(@source.n_define_calls, 1)

        test_define_number("2", "4")
        assert_equal(@source.n_define_calls, 1)

        test_define_number("3", "9")
        assert_equal(@source.n_define_calls, 2)

        test_define_number("4", "16")
        assert_equal(@source.n_define_calls, 3)

        test_define_number("2", "4")
        assert_equal(@source.n_define_calls, 3)

        test_define_number("5", "25")
        assert_equal(@source.n_define_calls, 4)

        # max_cache reached
        test_define_number("2", "4")
        assert_equal(@source.n_define_calls, 5)

        test_define_number("4", "16")
        assert_equal(@source.n_define_calls, 5)

        test_define_number("5", "25")
        assert_equal(@source.n_define_calls, 5)  
    end

    def test_match
        matches = @source.match("*", "prefix", "2")
        assert_equal(matches, {"db1" => ["4"]})
    end

    def test_match_number(number, result)
        matches = @source.cached_multiple_match(["db1"], "prefix", number)
        assert_equal(matches, {"db1" => [result]})
    end
    private :test_match_number

    def test_cached_multiple_define
        test_match_number("2", "4")
        assert_equal(@source.n_match_calls, 1)

        test_match_number("2", "4")
        assert_equal(@source.n_match_calls, 1)

        test_match_number("3", "9")
        assert_equal(@source.n_match_calls, 2)

        test_match_number("4", "16")
        assert_equal(@source.n_match_calls, 3)

        test_match_number("2", "4")
        assert_equal(@source.n_match_calls, 3)

        test_match_number("5", "25")
        assert_equal(@source.n_match_calls, 4)

        # max_cache reached
        test_match_number("2", "4")
        assert_equal(@source.n_match_calls, 5)

        test_match_number("4", "16")
        assert_equal(@source.n_match_calls, 5)

        test_match_number("5", "25")
        assert_equal(@source.n_match_calls, 5)  
    end

end
