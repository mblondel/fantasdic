# Fantasdic
# Copyright (C) 2009 Mathieu Blondel
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

class TestDictzip < Test::Unit::TestCase

    def setup
        @dict_file = File.join($test_data_dir,
                               "dictd_www.freedict.de_eng-swa.dict")
        @dict_file2 = File.join($test_data_dir, "freedict-eng-fra.dict")
        @dict_dz_file = File.join($test_data_dir,
                        "dictd_www.freedict.de_eng-swa.dict.dz")
        @dict_dz_file2 = File.join($test_data_dir, "freedict-eng-fra.dict.dz")

        @gz_file = File.join($test_data_dir, "edict.eucjp.gz")
    end

    def test_open_wrong
        [@dict_file, @dict_file2, @gz_file].each do |file|
            assert_raise Fantasdic::DictzipError do
                Fantasdic::Dictzip.new(file)
            end
        end
    end

    def test_small_size_read
        each_dict do |file, dzfile|
            assert_equal(file.read(10), dzfile.read(10))
            assert_equal(file.pos, dzfile.pos)

            assert_equal(file.read(20), dzfile.read(20))
            assert_equal(file.pos, dzfile.pos)   

            file.pos = 70
            dzfile.pos = 70

            assert_equal(file.pos, dzfile.pos)           
            assert_equal(file.read(100), dzfile.read(100))
            assert_equal(file.pos, dzfile.pos) 
        end
    end

    def test_big_size_read
        file = File.new(@dict_file2)
        dzfile = Fantasdic::Dictzip.new(@dict_dz_file2)

        file.pos = 70
        dzfile.pos = 70
        
        # max chunk size is 64KB so 100KB need two chunks
        assert_equal(file.read(100000), dzfile.read(100000))
        assert_equal(file.pos, dzfile.pos)      
        
        file.close
        dzfile.close
    end

    def test_eof
        each_dict do |file, dzfile|
            file.pos = 10000000
            dzfile.pos = 10000000
            assert_equal(file.read(100), dzfile.read(100))
        end
    end

    private

    def each_dict
        [[@dict_file, @dict_dz_file], [@dict_file2, @dict_dz_file2]].
        each do |file, dzfile|
            file = File.new(file)
            dzfile = Fantasdic::Dictzip.new(dzfile)
            
            begin
                yield file, dzfile
            ensure
                file.close
                dzfile.close
            end
        end    
    end

end
