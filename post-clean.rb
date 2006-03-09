# Copyright (C) 2005 Dafydd Harries, Mathieu Blondel

require 'fileutils'

clean_files = [
    'fantasdic.desktop',
    'bin/fantasdic',
    'lib/fantasdic/config.rb',
    'lib/fantasdic/version.rb',
    ]

for file in clean_files
    puts "rm -f #{file}"
    FileUtils.rm_f(file)
end