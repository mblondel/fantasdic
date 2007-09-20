# Copyright 2005 Laurent Sansonetti
# Copyright 2007 Mathieu Blondel

base_path = File.join(config('data-dir'), 'gnome', 'help', 'fantasdic')

Dir.glob("*.omf").each do |file|
    case file
        when /fantasdic-(.*).omf/
            lang = $1
            path = File.join(base_path, lang, 'fantasdic.xml')
            data = IO.read(file)
            data.sub!(/PATH_TO_DOC_FILE/, path)
            File.open(file, 'w') { |io| io.puts data }
    end
end