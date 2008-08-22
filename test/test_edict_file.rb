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
$test_data_dir = File.expand_path(File.join(test_dir, "data"))
$LOAD_PATH.unshift(lib_dir)

require "test/unit"
require "fantasdic"
require "fantasdic/sources/edict_file"

$KCODE = "u"

class TestEdictFileSource < Test::Unit::TestCase
    include Fantasdic::Source

    private

    def test_define(source)
        defs = source.define("*", "龜甲")
        assert_equal(defs.length, 2)

        assert_equal(defs[0].word, "龜甲")
        assert_equal(defs[0].body, "龜甲 [きこう] /(oK) (n) tortoise shell/")

        assert_equal(defs[1].word, "龜甲")
        assert_equal(defs[1].body, "龜甲 [きっこう] /(oK) (n) tortoise shell/")

        defs = source.define("*", "きこう")
        assert_equal(defs.length, 1)

        assert_equal(defs[0].word, "きこう")
        assert_equal(defs[0].body, "龜甲 [きこう] /(oK) (n) tortoise shell/")

        defs = source.define("*", "tortoise")
        assert_equal(defs.length, 0)
    end

    def test_match_prefix(source)
        matches = source.match("*", "prefix", "遙")
        key = matches.keys.first
        assert_equal(matches,
                     {key=>["遙々", "遙か", "遙かに", "遙遙"]})

        matches = source.match("*", "prefix", "かめ")
        assert_equal(matches,
                     {key=>["龜の甲", "龜の子", "龜の手", "龜虫", "龜卜"]})

        matches = source.match("*", "prefix", "(adv)")
        assert_equal(matches,
                     {key=>["(adv) from afar/over a great distance/all the way",
                         "(adv) from afar/over a great distance/all the way"]})

    end

    def test_match_suffix(source)
        matches = source.match("*", "suffix", "甲")
        key = matches.keys.first
        assert_equal(matches,
                     {key=>["龜の甲", "龜甲", "龜甲"]})

        matches = source.match("*", "suffix", "こう")
        assert_equal(matches,
                     {key=>["龜の甲", "龜甲", "龜甲"]})

        matches = source.match("*", "suffix", "tion")
        assert_equal(matches,
                     {key=>["(oK) (n) tortoise-shell divination",
                            "(oK) (n) tortoise-shell divination"]})
    end

    def test_match_word(source)
        matches = source.match("*", "word", "龜甲")
        key = matches.keys.first
        assert_equal(matches,
                     {key=>["龜甲", "龜甲"]})

        matches = source.match("*", "word", "きこう")
        assert_equal(matches,
                     {key=>["龜甲"]})

        matches = source.match("*", "word", "tortoise")
        assert_equal(matches,
                     {key=>["(oK) (n) tortoise shell",
                           "(oK) (n) tortoise shell",
                           "(oK) (n) tortoise shell"]})
    end

    def test_match_substring(source)
        matches = source.match("*", "substring", "龜")
        key = matches.keys.first
        assert_equal(matches,
                     {key=>["龜の甲", "龜の子", "龜の手", "龜鑑",
                            "龜甲", "龜甲", "龜虫", "龜卜", "龜卜", "龜裂"]})

        matches = source.match("*", "substring", "めのこ")
        assert_equal(matches,
                     {key=>["龜の甲", "龜の子"]})

        matches = source.match("*", "substring", "-shell")
        assert_equal(matches,
                     {key=>["(oK) (n) tortoise-shell divination",
                            "(oK) (n) tortoise-shell divination"]})
    end

    public

    utf8 = {:filename => File.join($test_data_dir, "edict.utf8"),
            :encoding => "UTF-8"}
    utf8gz = {:filename => File.join($test_data_dir, "edict.utf8.gz"),
                :encoding => "UTF-8"}
    eucjp = {:filename => File.join($test_data_dir, "edict.eucjp"),
                :encoding => "EUC-JP"}
    eucjpgz = {:filename => File.join($test_data_dir, "edict.eucjp.gz"),
                :encoding => "EUC-JP"}

    [EdictFileRuby, EdictFileEgrep].each do |klass|
        [utf8, utf8gz, eucjp, eucjpgz].each do |hash|
            encoding = hash[:encoding].gsub("-", "").downcase

            # EUC-JP is not supported by EdictFileRuby implementation
            next if klass == EdictFileRuby and encoding == "eucjp"

            klass_short = klass.to_s.split("::").last.downcase
            gz = hash[:filename] =~ /gz$/ ? "gz" : "nogz"

            method = "test_#{klass_short}_#{encoding}_#{gz}_define"
            define_method(method) do
                send("test_define", klass.new(hash))
            end

            ["prefix", "suffix", "word", "substring"].each do |match|
                method = "test_#{klass_short}_#{encoding}_#{gz}_#{match}"
                define_method(method) do
                    send("test_match_#{match}", klass.new(hash))
                end
            end
        end
    end

end
