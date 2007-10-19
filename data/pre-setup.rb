# Copyright (C) 2007 Mathieu Blondel

# Copying documentation figures
require 'fileutils'

FileUtils.mkdir_p('doc/fantasdic/html/')

Dir.glob("gnome/help/fantasdic/**/*").each do |file_to_copy|
    file = file_to_copy.gsub("gnome/help/fantasdic/", "")
    file = File.join("doc/fantasdic/html/", file)
    if File.directory? file_to_copy
        FileUtils.mkdir_p(file)
    else
        FileUtils.cp(file_to_copy, file)
    end
end

Dir.new("doc/fantasdic/html").each do |dir|
    next if [".", ".."].include? dir
    dir = File.join("doc/fantasdic/html", dir)
    if File.directory? dir
        FileUtils.rm_f(File.join(dir, "fantasdic.xml"))
        FileUtils.rm_f(Dir.glob(File.join(dir, "*.mo")))
    end
end

