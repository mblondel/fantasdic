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

class TestBinarySearch < Test::Unit::TestCase

    def test_array_binary_search
        arr = %w(a b c d e f g h i j k l m n o p q r s t u v w x y z)

        arr.each_with_index do |value, index|
            assert_equal(arr.binary_search(value) { |a,b| a <=> b }, index)
        end

        assert_equal(arr.binary_search("notfound") { |a,b| a <=> b }, nil)
    end

    def test_array_binary_search_all_1
        arr = %w(a b c d e f g h i j k l m n o p q r s t u v w x y z)

        arr.each_with_index do |value, index|
            assert_equal(arr.binary_search_all(value) { |a,b| a <=> b },
                         [index])
        end

        assert_equal(arr.binary_search_all("notfound") { |a,b| a <=> b }, [])
    end

    def test_array_binary_search_all_2
        arr = %w(a b c d e f g h i i i i i i i i i r s t u v w x y z)

        assert_equal(arr.binary_search_all("i") { |a,b| a <=> b },
                    (8..16).to_a)
    end

end
