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
require "fantasdic/sources/virtual_dictionary"
require "fantasdic/sources/dictd_file"
require "fantasdic/sources/edict_file"

class TestVirtualDictionarySource < Test::Unit::TestCase

    def setup
        @config_file = File.expand_path(File.join($test_data_dir,
                                                  "config.yaml"))
        @edict_file = File.join($test_data_dir, "edict.utf8")
        @dict_index_file = File.join($test_data_dir, "freedict-wel-eng.index")


        prefs = Fantasdic::PreferencesBase.new(@config_file)
        prefs.dictionaries = ["edict", "dictdfile"]
        prefs.dictionaries_infos["edict"] = {
            :source => "EdictFile",
            :filename => @edict_file,
            :all_dbs => true,
            :sel_dbs => [],
            :encoding => "UTF-8"}
        prefs.dictionaries_infos["dictdfile"] = {
            :source => "DictdFile",
            :all_dbs => true,
            :sel_dbs => [],
            :filename => @dict_index_file}

        @source = Fantasdic::Source::VirtualDictionaryBase.new(prefs)
    end

    def test_define
        defs = @source.define("*", "pedair")
        assert_equal(defs.length, 1)
        assert_equal(defs.first.body, "pedair\n   four")
    end

end
