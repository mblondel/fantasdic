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

class TestUtils < Test::Unit::TestCase

    def test_utf8_length
        assert_equal("テスト".utf8_length, 3)
    end

    def test_utf8_slice
        assert_equal("一二三四五".utf8_slice(1..3), "二三四")
    end

    def test_utf8_reverse
        assert_equal("テスト".utf8_reverse, "トステ")
    end

    def test_latin
        assert_equal("English".latin?, true)
        assert_equal("Français".latin?, true)
        assert_equal("日本語".latin?, false)
        assert_equal("Русский".latin?, false)
    end

    def test_hiragana        
        assert_equal("ひらがな".hiragana?, true)
        assert_equal("ひらがな".katakana?, false)
        assert_equal("ひらがな".kanji?, false)
    end

    def test_katakana        
        assert_equal("カタカナ".hiragana?, false)
        assert_equal("カタカナ".katakana?, true)
        assert_equal("カタカナ".kanji?, false)
    end

    def test_kanji      
        assert_equal("漢字".hiragana?, false)
        assert_equal("漢字".katakana?, false)
        assert_equal("漢字".kanji?, true)
    end

    def test_kana       
        assert_equal("ひらがな".kana?, true)
        assert_equal("カタカナ".kana?, true)
        assert_equal("漢字".kana?, false)
    end

    def test_japanese      
        assert_equal("ひらがな".japanese?, true)
        assert_equal("カタカナ".japanese?, true)
        assert_equal("漢字".japanese?, true)
    end

    def test_push_head(ele)
        arr = []
        arr.push_head(1)
        arr.push_head(2)
        assert_equal(arr, [2,1])
    end

    def test_push_tail(ele)
        arr = []
        arr.push_tail(1)
        arr.push_tail(2)
        assert_equal(arr, [1,2])
    end

    def test_pop_head
        arr = [1,2]
        ret = arr.pop_head
        assert_equal(ret, 1)
        assert_equal(arr, [2])
        ret = arr.pop_head
        assert_equal(ret, 2)
        assert_equal(arr, [])
        ret = arr.pop_head
        assert_equal(ret, nil)
    end

    def test_pop_tail
        arr = [1,2]
        ret = arr.pop_tail
        assert_equal(ret, 2)
        assert_equal(arr, [1])
        ret = arr.pop_tail
        assert_equal(ret, 1)
        assert_equal(arr, [])
        ret = arr.pop_tail
        assert_equal(ret, nil)
    end

    def test_which
        assert_equal(File.which("true"), "/bin/true")
        assert_equal(File.which("pgmthatdoesntexist"), nil)
    end

    def test_enumerable_sum
        assert_equal([1,2,3,4].sum, 10)
        assert_equal([[1],[2],[3,4]].sum, [1,2,3,4])
        assert_equal([[1],[2],[3,4]].sum.sum, 10)
    end

end
