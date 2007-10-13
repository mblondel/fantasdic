# Stardict to dictd format converter
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

def puts_def(dic_file, headword, offset, size)
    if size < 10000 and not headword.empty?
        dic_file.seek(offset)
        definition = dic_file.read(size)
    
        puts "_____\n\n#{headword}"
        puts " "
        puts definition
        puts " "
    
    end
end

def parse(basename)
  
    idx_file = File.open(basename + '.idx')
    dic_file = File.open(basename + '.dict')
      
    i = 0
    
    headword = ''
    offset = ''
    size = ''
    
    in_headword = true
    in_offset = false
    in_size = false
    
    idx_file.each_line do |line|
    
        line.split(//).each do |char|
            if in_headword 
                if char != "\0"
                    headword += char
                else
                    in_headword = false
                    in_offset = true
                end
            elsif in_offset
                offset += char
    
                if offset.length == 4
                    offset = offset.unpack("N*")[0]
                    in_offset = false
                    in_size = true
                end
            elsif in_size
                size += char
    
                if size.length == 4
                    size = size.unpack("N*")[0]
                    in_size = false
                    in_headword = true
    
                    puts_def(dic_file, headword, offset, size)
    
                    headword = ''
                    offset = ''
                    size = ''
                
                    i += 1
                end       
            end
    
        end
    
        
    end
    idx_file.close
    dic_file.close
end

def get_ifo_infos(file)
    hsh_basename = {}
    File.open(file).each_line do |line|
        k,v = line.split('=')
        hsh_basename[k] = v unless v.nil?
    end
    hsh_basename
end

def convert_all
    bz2_files = Dir.glob('*.bz2')

    Dir.mkdir('tmp/') unless FileTest.exists? 'tmp/'
    Dir.mkdir('output/') unless FileTest.exists? 'output/'
    Dir.chdir('tmp/')

    bz2_files.each do |bz2_file|
        puts "Extracting #{bz2_file}..."
        system("tar xfj #{'../' + bz2_file}")
    end

    dic_dirs = Dir.glob('*')

    hsh_basename = {}
    hsh_dicname = {}

    dic_dirs.each do |dir|
        Dir.chdir(dir)

        ifo_file = Dir.glob('*.ifo')[0]
        dicname = get_ifo_infos(ifo_file)['bookname']
        hsh_dicname[dir] = dicname

        basename = ifo_file[0...-4]
        hsh_basename[dir] = basename

        File.rename(basename + '.dict.dz', basename + '.dict.gz')

        puts "Gunzipping #{basename + '.dict.dz...'}"
        system("gunzip #{basename + '.dict.gz'}")

        Dir.chdir('../')
    end

    Dir.chdir('../output')

    dic_dirs.each do |dir|
        basename = hsh_basename[dir]
        basefile = File.join('../tmp/', dir, basename)
        dicname = hsh_dicname[dir]

        script_path = if $0.split(//).first == '/'
            $0
        else
            File.join('../', $0)
        end

        File.open('script.sh', 'w') do |f|
            f.puts("ruby #{script_path} #{basefile}" + \
                   " | iconv -f utf8 -t utf8 -c" + \
                   " | dictfmt -c5 --utf8 -s \"#{dicname}\" #{basename}")
        end

        puts "Creating dict #{basename}..."
        `sh script.sh`
        puts "Gzipping (dictzip) #{basename}..."
        system("dictzip #{basename + '.dict'}")

        File.delete('script.sh')
    end

    Dir.chdir('../')
    system('rm -rf tmp/')
end

def usage
    puts ""
    puts "Usage"
    puts ""
    puts "ruby stardict2dictd.rb basename"
    puts ""
    puts "\tOutputs word definitons in a dictfmt compatible format "
    puts "\tbased upon basename.idx and basename.dict (gunzipped dict file)."
    puts ""
    puts "\tTo gunzip a .dict.dz file, rename it to .dict.gz first."
    puts ""
    puts "\tThe produced output can be piped into the dictfmt utility. Ex:"
    puts ""
    puts "\truby stardic2dictd.rb basename | dictfmt -c5 --utf8 -s \"Dict" + \
         " name\" dictname"
    puts ""
    puts "\tor, to ensure that the utf8 output is not corrupted,"
    puts ""
    puts "\truby stardict2dictd.rb basename | iconv -f utf-8 -t utf-8 " + \
         "-c | dictfmt -c5 --utf8 -s \"Dict name\" dictname"
    puts ""
    puts "ruby stardict2dictd.rb --all"
    puts ""
    puts "\tCreates dictd compatible dictionary and index files for "
    puts "\t.bz2 stardict dictionary tarballs found in the current directory"
    puts "\t(directory from where the script is called not where the"
    puts "\tscript is). "
    puts ""
    puts "\tFiles created are put in output/."
    puts ""
end

if $0 == __FILE__

    if ARGV.length != 1 or ARGV[0] == '-h' or ARGV[0] == '--help'
        usage

    elsif ARGV[0] == '--all'
        convert_all        
    else
        parse(ARGV[0])
    end
end