# Copyright (C) 2007 Mathieu Blondel

# Copying documentation figures
require 'fileutils'
FileUtils.mkdir_p('doc/fantasdic/html/')
FileUtils.cp_r(Dir.glob('gnome/help/fantasdic/*'), 'doc/fantasdic/html/')
Dir.new("doc/fantasdic/html").each do |dir|
    next if [".", ".."].include? dir
    dir = File.join("doc/fantasdic/html", dir)
    if File.directory? dir
        FileUtils.rm_f(File.join(dir, "fantasdic.xml"))
        FileUtils.rm_f(Dir.glob(File.join(dir, "*.mo")))
    end
end