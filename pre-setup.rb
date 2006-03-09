# Copyright (C) 2004-2005 Dafydd Harries
#
# Loosely based on pre-setup.rb from rbbr by Masao Mutoh.
#
# Modified by Mathieu Blondel for fantasdic

basename = "fantasdic"
config = Config::CONFIG
podir = srcdir_root + "/po/"

# Create MO files.

Dir.glob("po/*.po") do |file|
    lang = /po\/(.*)\.po/.match(file).to_a[1]
    mo_path_bits = ['data', 'locale', lang, 'LC_MESSAGES']
    mo_path = File.join(mo_path_bits)

    (0 ... mo_path_bits.length).each do |i|
        path = File.join(mo_path_bits[0 .. i])
        puts path
        Dir.mkdir(path) unless FileTest.exists?(path)
    end
    
    if RUBY_PLATFORM =~ /win32/
        cmd = "ruby c:/ruby/bin/rmsgfmt po/#{lang}.po "
        cmd += "-o #{mo_path}/#{basename}.mo"
	    system(cmd)
    else
	    system("msgfmt po/#{lang}.po -o #{mo_path}/#{basename}.mo")
    end

    raise "msgfmt failed on po/#{lang}.po" if $? != 0
end