# Copyright 2005 Laurent Sansonetti
# Copyright 2007 Mathieu Blondel

# Portable which
def which(pgm)
    ENV['PATH'].split(":").each do |dir|
        path = File.join(dir, pgm)
        return path if File.executable? path
    end
    return nil
end

sk = which("scrollkeeper-update")
if sk
    Dir.glob("*.omf").each do |file|
        system("scrollkeeper-update -q #{file}")
    end
else
    $stderr.puts "scrollkeeper-update cannot be found," + \
                 "is Scrollkeeper correctly installed?"
end