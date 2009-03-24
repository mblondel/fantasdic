# Fantasdic
# Copyright (C) 2009 Mathieu Blondel
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

require "zlib"

module Fantasdic

class DictzipError < IOError; end

class Dictzip

    # For gzip-compatible header, as defined in RFC 1952 

    # Magic for GZIP            
    GZ_MAGIC1 =    0x1f  # First magic byte                        
    GZ_MAGIC2 =    0x8b  # Second magic byte                       

    # FLaGs (bitmapped)      
    GZ_FTEXT =     0x01  # Set for ASCII text                      
    GZ_FHCRC =     0x02  # Header CRC16                            
    GZ_FEXTRA =    0x04  # Optional field (random access index)    
    GZ_FNAME =     0x08  # Original name                           
    GZ_COMMENT =   0x10  # Zero-terminated, human-readable comment 
    GZ_MAX =          2  # Maximum compression                     
    GZ_FAST =         4  # Fasted compression                      

                                    
    GZ_OS_FAT =       0  # FAT filesystem (MS-DOS, OS/2, NT/Win32) 
    GZ_OS_AMIGA =     1  # Amiga                                   
    GZ_OS_VMS =       2  # VMS (or OpenVMS)                        
    GZ_OS_UNIX =      3      # Unix                                    
    GZ_OS_VMCMS =     4      # VM/CMS                                  
    GZ_OS_ATARI =     5      # Atari TOS                               
    GZ_OS_HPFS =      6      # HPFS filesystem (OS/2, NT)              
    GZ_OS_MAC =       7      # Macintosh                               
    GZ_OS_Z =         8      # Z-System                                
    GZ_OS_CPM =       9      # CP/M                                    
    GZ_OS_TOPS20 =   10      # TOPS-20                                 
    GZ_OS_NTFS =     11      # NTFS filesystem (NT)                    
    GZ_OS_QDOS =     12      # QDOS                                    
    GZ_OS_ACORN =    13      # Acorn RISCOS                            
    GZ_OS_UNKNOWN = 255      # unknown                                 

    GZ_RND_S1 =      'R' # First magic for random access format    
    GZ_RND_S2 =      'A' # Second magic for random access format   

    GZ_ID1 =          0  # GZ_MAGIC1                               
    GZ_ID2 =          1  # GZ_MAGIC2                               
    GZ_CM =           2  # Compression Method (Z_DEFALTED)         
    GZ_FLG =          3  # FLaGs (see above)                       
    GZ_MTIME =        4  # Modification TIME                       
    GZ_XFL =          8  # eXtra FLags (GZ_MAX or GZ_FAST)         
    GZ_OS =           9  # Operating System                        
    GZ_XLEN =        10  # eXtra LENgth (16bit)                    
    GZ_FEXTRA_START = 12  # Start of extra fields                   
    GZ_SI1 =         12  # Subfield ID1                            
    GZ_SI2 =         13      # Subfield ID2                            
    GZ_SUBLEN =      14  # Subfield length (16bit)                 
    GZ_VERSION =     16      # Version for subfield format             
    GZ_CHUNKLEN =    18  # Chunk length (16bit)                    
    GZ_CHUNKCNT =    20  # Number of chunks (16bit)                
    GZ_RNDDATA =     22  # Random access data (16bit)

    attr_accessor :pos

    def initialize(filename)
        @file = File.new(filename, "rb")
        read_header
        read_footer
        compute_offsets
        @pos = 0
    end

    def path
        @file.path
    end

    def close
        @file.close
    end

    def read(size)
        start = @pos
        end_ = start + size

        first_chunk  = start / @chunk_length
        first_offset = start % @chunk_length
        last_chunk   = end_ / @chunk_length
        n_chunks = last_chunk - first_chunk + 1
        last_offset  = (n_chunks - 1) * @chunk_length + (end_ % @chunk_length)
        
        zstream = Zlib::Inflate.new(-Zlib::MAX_WBITS)
        #zstream.avail_out = ((0xffff - 12) * 0.89).ceil
    
        uncompressed = ""

        if first_chunk >= @offsets.length
            nil
        else
            self.pos_internal = @offsets[first_chunk]

            first_chunk.upto(last_chunk) do |i|
                compressed = @file.read(@chunks[i])
                uncompressed += zstream.inflate(compressed)
            end

            zstream.close

            @pos += size

            uncompressed.slice(first_offset...last_offset)
        end
    end

    private

    def pos_internal; @file.pos; end

    def pos_internal=(point); @file.pos = point; end

    def read_header
        @header_length = GZ_XLEN - 1

        id1 = read_byte_internal
        id2 = read_byte_internal
        
        raise DictzipError, "Not gzip" if id1 != GZ_MAGIC1 or id2 != GZ_MAGIC2

        @method = read_byte_internal
        @flags = read_byte_internal
        @mtime = read_le32
        @extra_flags = read_byte_internal
        @os = read_byte_internal

        if (@flags & GZ_FEXTRA) != 0
            extra_length = read_le16
            @header_length += extra_length + 2
            si1 = read_char_internal
            si2 = read_char_internal
        
            if si1 != GZ_RND_S1 or si2 != GZ_RND_S2
                raise DictzipError, "Not a dictzip file"
            else
                sub_length    = read_le16
                @version      = read_le16
                
                if @version != 1
                    raise DictzipError, 
                        "dzip header version %d not supported" % @version
                end
                
                @chunk_length  = read_le16
                @chunk_count   = read_le16
                
                raise DictzipError, "No chunks found" if @chunk_count <= 0

                @chunks = []

                @chunk_count.times do |i|
                    @chunks[i]  = read_le16
                end
            end
        else
            raise DictzipError, "This is file is a plain gz file!"            
        end

        if (@flags & GZ_FNAME) != 0 # FIXME! Add checking against header len 
            @orig_filename = read_null_terminated_string
            @header_length += @orig_filename.length + 1 # +1 to account for \0
        else
            @orig_filename = ""
        end
   
        if (@flags & GZ_COMMENT) != 0 # FIXME! Add checking for header len
            @comment = read_null_terminated_string
            @header_length += @comment.length + 1
        else
            @comment = ""
        end

        if (@flags & GZ_FHCRC) != 0
            2.times { read_byte_internal }
            @header_length += 2
        end

        if pos_internal != @header_length + 1
                raise DictzipError, 
                    "File position (%d) != header length + 1 (%d)" % \
                        [pos_internal, @header_length]
        end
    end

    def read_footer
        @file.seek(-8, IO::SEEK_END)
        @crc     = read_le32
        @length  = read_le32
        @compressed_length = pos_internal
    end

    def compute_offsets
        @offsets = []
        offset = @header_length + 1

        @chunk_count.times do |i|
            @offsets[i] = offset
            offset += @chunks[i]
        end
    end

    def read_byte_internal
        @file.getc
    end

    def read_char_internal
        read_byte_internal.chr
    end

    def read_le16
        val  = read_byte_internal
        val |= read_byte_internal << 8
    end

    def read_le32
        val  = read_byte_internal
        val |= read_byte_internal <<  8
        val |= read_byte_internal << 16
        val |= read_byte_internal << 24
    end

    def read_null_terminated_string
        str = ""
        while c = read_byte_internal
            break if c == 0 or @file.eof?
            str += c.chr
        end
        str
    end

end

end