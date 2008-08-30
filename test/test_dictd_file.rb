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
require "fantasdic/sources/dictd_file"

class TestDictdFileSource < Test::Unit::TestCase
    include Fantasdic::Source

    def setup
        @index_file = File.join($test_data_dir, "freedict-wel-eng.index")
        @dict_file = File.join($test_data_dir, "freedict-wel-eng.dict")
        @dict_dz_file = File.join($test_data_dir, "freedict-wel-eng.dict.dz")
    end

    def test_binary_search
        DictdIndex.open(@index_file) do |index|
            res = index.binary_search("notfound") do |s1, s2|
                s1 <=> s2
            end
            assert_equal(res, nil)

            res = index.binary_search("cloc") do |s1, s2|
                s1 <=> s2
            end
            assert_equal(res, 2005)
        end
    end

    def test_seek_prev_offset
        DictdIndex.open(@index_file) do |index|
            assert_equal(index.get_prev_offset(52), 25)
            assert_equal(index.get_prev_offset(2005), 1994)
            assert_equal(index.get_prev_offset(25), nil)
        end
    end

    def test_seek_next_offset
        DictdIndex.open(@index_file) do |index|
            assert_equal(index.get_next_offset(52), 72)
            assert_equal(index.get_next_offset(9462), 9472)
            assert_equal(index.get_next_offset(9472), nil)
        end
    end

    def test_match_prefix
        DictdIndex.open(@index_file) do |index|
            assert_equal(index.match_prefix("ca").map { |a| a.first },
["cadair", "cadnawes", "cadno", "cadw", "cael", "caerdydd", "caeredin",
 "caerefrog", "caerludd", "caint", "caled", "calon", "canol", "cant",
 "canu", "cap", "capel", "car", "caredig", "cario", "carreg", "cartref",
 "caru", "carw", "castell", "cath", "cau", "cawrfil", "caws"])

            assert_equal(index.match_prefix("notfound").map { |a| a.first },
                         [])

        end
    end

    def test_match_exact
        DictdIndex.open(@index_file) do |index|
            assert_equal(index.match_exact("ca").map { |a| a.first },
                         [])

            assert_equal(index.match_exact("caredig").map { |a| a.first },
                         ["caredig"])            
        end
    end

    def test_match_suffix
        DictdIndex.open(@index_file) do |index|
            assert_equal(index.match_suffix("din").map { |a| a.first },
                         ["caeredin", "lladin"])

            assert_equal(index.match_suffix("notfound").map { |a| a.first },
                         [])
        end
    end

    def test_match_substring
        DictdIndex.open(@index_file) do |index|
            assert_equal(index.match_substring("hufein").map { |a| a.first },
                         ["rhufeinaidd", "rhufeiniad", "rhufeinig",
                          "rhufeiniwr"])

            assert_equal(index.match_substring("notfound").map { |a| a.first },
                         [])
        end
    end

    def test_match_word
        DictdIndex.open(@index_file) do |index|
            assert_equal(index.match_word("os").map { |a| a.first },
                         ["os", "os gwelwch yn dda"])

            assert_equal(index.match_word("notfound").map { |a| a.first },
                         [])
        end
    end

    def test_get_word_list
        DictdIndex.open(@index_file) do |index|
            assert_equal(index.get_word_list[0..24].map { |a| a.first },
                        ["00databasealphabet",
                        "00databasedictfmt11010",
                        "00databaseinfo",
                        "00databaseshort",
                        "00databaseurl",
                        "00databaseutf8",
                        "a",
                        "abad",
                        "abades",
                        "abaty",
                        "aber",
                        "ac",
                        "achos",
                        "achosi",
                        "adda",
                        "adeg",
                        "adeiladu",
                        "aderyn",
                        "adnabod",
                        "adref",
                        "afal",
                        "afon",
                        "agor",
                        "ail",
                        "ail ar bymtheg"])
        end
    end
end
