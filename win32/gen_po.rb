# Fantasdic
# Copyright (C) 2006 - 2007 Mathieu Blondel
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

Dir.chdir("../")

$LOAD_PATH.unshift("../ruby-gettext/lib/")  

require 'rbconfig'
if /mingw|mswin|mswin32/ =~ RUBY_PLATFORM
    ENV['PATH'] = %w(bin lib).collect{|dir|
        "#{Dir.pwd}\\..\\GTK\\#{dir};"
    }.join('') + ENV['PATH']
end

require "gettext"      
require "gettext/poparser"

basename = "fantasdic"

Dir.glob("po/*.po") do |file|
    lang = /po\/(.*)\.po/.match(file).to_a[1]
    mo_path_bits = ['data', 'locale', lang, 'LC_MESSAGES']
    mo_path = File.join(mo_path_bits)

    (0 ... mo_path_bits.length).each do |i|
        path = File.join(mo_path_bits[0 .. i])
        puts path
        Dir.mkdir(path) unless FileTest.exists?(path)
    end

	parser = GetText::PoParser.new
	data = MOFile.new
	parser.parse(File.open("po/#{lang}.po").read, data)
	data.save_to_file("#{mo_path}/#{basename}.mo")
end

