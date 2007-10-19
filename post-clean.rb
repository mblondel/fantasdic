# Copyright (C) 2005 Dafydd Harries, Mathieu Blondel

require 'fileutils'

clean_files = [
    'bin/fantasdic',
    'lib/fantasdic/config.rb',
    'lib/fantasdic/version.rb',
    'lib/fantasdic/authors.rb',
    'lib/fantasdic/translators.rb',
    'lib/fantasdic/documenters.rb'
    ]

for file in clean_files
    puts "rm -f #{file}"
    FileUtils.rm_f(file)
end