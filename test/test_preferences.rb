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
$config_file = File.expand_path(File.join(test_dir, "data", "config.yaml"))
$LOAD_PATH.unshift(lib_dir)

require "test/unit"
require "fileutils"
require "fantasdic"

class TestPreferences < Test::Unit::TestCase

    def setup
        @prefs = Fantasdic::PreferencesBase.new($config_file)
    end

    def teardown
        @prefs = nil
    end

    def test_attributes
        assert_equal(@prefs.scan_clipboard, false)
        assert_equal(@prefs.window_position, [196, 110])
        assert_equal(@prefs.history_nb_rows, 15)
        assert_equal(@prefs.dictionaries_infos,
                    {"English"=>
                        {:login=>"",
                        :password=>"",
                        :name => "English",
                        :all_dbs=>false,
                        :selected=>1,
                        :sel_dbs=>["foldoc", "gcide", "wn", "jargon"],
                        :avail_strats=>
                            ["prefix",
                            "soundex",
                            "regexp",
                            "exact",
                            "word",
                            "substring",
                            "lev",
                            "re",
                            "suffix"],
                        :auth=>false,
                        :server=>"dict.org",
                        :sel_strat=>"define",
                        :port=>"2628"},
                    "Spanish"=>
                        {:login=>"",
                        :password=>"",
                        :name => "Spanish",
                        :all_dbs=>true,
                        :selected=>1,
                        :sel_dbs=>[],
                        :avail_strats=>
                            ["prefix",
                            "soundex",
                            "regexp",
                            "exact",
                            "word",
                            "substring",
                            "lev",
                            "re",
                            "suffix"],
                        :auth=>false,
                        :server=>"es.dict.org",
                        :sel_strat=>"define",
                        :port=>"2628"},
                    "English <-> French"=>
                        {:login=>"",
                        :password=>"",
                        :name => "English <-> French",
                        :all_dbs=>false,
                        :selected=>1,
                        :sel_dbs=>["eng-fra", "fra-eng"],
                        :avail_strats=>
                            ["prefix",
                            "soundex",
                            "regexp",
                            "exact",
                            "word",
                            "substring",
                            "lev",
                            "re",
                            "suffix"],
                        :auth=>false,
                        :server=>"dict.org",
                        :sel_strat=>"define",
                        :port=>"2628"},
                    "Japanese"=>
                        {:login=>"",
                        :password=>"",
                        :name => "Japanese",
                        :all_dbs=>true,
                        :selected=>1,
                        :sel_dbs=>[],
                        :avail_strats=>
                            ["prefix",
                            "soundex",
                            "regexp",
                            "exact",
                            "word",
                            "substring",
                            "lev",
                            "re",
                            "suffix"],
                        :auth=>false,
                        :server=>"nihongobenkyo.org",
                        :sel_strat=>"define",
                        :port=>"2628"}})
        assert_equal(@prefs.last_search,
                    {:strategy=>"define", :word=>"test",
                     :dictionary=>"English"})
    end

    def test_update_dictionary
        assert_not_equal(@prefs.dictionaries_infos["Japanese"],
                         {:name=>"Japanese"})
        @prefs.update_dictionary("Japanese", {})
        assert_equal(@prefs.dictionaries_infos["Japanese"],
                     {:name=>"Japanese"})
    end

    def test_add_dictionary
        assert_not_equal(@prefs.dictionaries_infos["Japanese"],
                         {:name => "Japanese"})
        @prefs.add_dictionary("Japanese", {})
        assert_equal(@prefs.dictionaries_infos["Japanese"],
                     {:name => "Japanese"})

        assert_equal(@prefs.dictionaries_infos.has_key?("New"), false)
        @prefs.add_dictionary("New", {})
        assert_equal(@prefs.dictionaries_infos["New"],
                     {:name=>"New"})        
    end

    def test_delete_dictionary
        assert_equal(@prefs.dictionaries.include?("Japanese"), true)
        assert_equal(@prefs.dictionaries_infos.has_key?("Japanese"), true)
        @prefs.delete_dictionary("Japanese")
        assert_equal(@prefs.dictionaries.include?("Japanese"), false)
        assert_equal(@prefs.dictionaries_infos.has_key?("Japanese"), false)

        @prefs.delete_dictionary("DontExist")
    end

    def test_dictionary_up
        assert_equal(@prefs.dictionaries.index("English"), 0)
        @prefs.dictionary_up("English")
        assert_equal(@prefs.dictionaries.index("English"), 1)

        assert_equal(@prefs.dictionaries.index("Japanese"), 3)
        @prefs.dictionary_up("Japanese")
        assert_equal(@prefs.dictionaries.index("Japanese"), 3)

        @prefs.dictionary_up("DontExist")
    end

    def test_dictionary_down
        assert_equal(@prefs.dictionaries.index("English"), 0)
        @prefs.dictionary_down("English")
        assert_equal(@prefs.dictionaries.index("English"), 0)

        assert_equal(@prefs.dictionaries.index("Japanese"), 3)
        @prefs.dictionary_down("Japanese")
        assert_equal(@prefs.dictionaries.index("Japanese"), 2)

        @prefs.dictionary_down("DontExist")
    end

    def test_dictionary_replace_name
        assert_equal(@prefs.dictionary_exists?("Japanese"), true)
        assert_equal(@prefs.dictionary_exists?("New"), false)
        @prefs.dictionary_replace_name("Japanese", "New")
        assert_equal(@prefs.dictionary_exists?("Japanese"), false)
        assert_equal(@prefs.dictionary_exists?("New"), true)

        @prefs.dictionary_replace_name("DontExist", "New")
    end

    def test_dictionary_exists
        assert_equal(@prefs.dictionary_exists?("Japanese"), true)
        assert_equal(@prefs.dictionary_exists?("DontExist"), false)
    end

    def test_save
        begin
            temp_file = "config_temp.yaml"
            FileUtils.cp($config_file, temp_file)
            prefs = Fantasdic::PreferencesBase.new(temp_file)
            prefs.view_statusbar = false
            prefs.save!

            prefs2 = Fantasdic::PreferencesBase.new(temp_file)
            assert_equal(prefs2.view_statusbar, prefs.view_statusbar)
        ensure
            FileUtils.rm_f(temp_file)
        end
    end

end
