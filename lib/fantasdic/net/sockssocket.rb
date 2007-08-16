=begin

= $RCSfile: sockssocket.rb,v $ -- Class Net::SOCKSSocket supports connections based on the SOCKS5 protocol.

== Info
  'SOCKSSocket written in Ruby' project

== Copyright
  Copyright (C) 2006 Ryota Tokiwa
  All rights reserved.

== Licence
  This program is licenced under Ruby's License.

== Requirements
  This program requires Ruby 1.8.0 or lator .

== Version
  $Id: sockssocket.rb,v 1.1.1 2006/11/15 00:00:00 rtokiwa Exp $

== class SOCKSSocket
    
: initialize
    override

: open
    override

=== Instance Methods

=end
require 'socket'

#Thread.exit if defined? SOCKSSocket
undef SOCKSSocket if defined? SOCKSSocket

module Net
  class SOCKSSocketError < SocketError; end

  class SOCKSSocket < TCPSocket
    VERSION = "1.0.0"
    class << self
      attr_reader :socks_addr, :socks_port, :socks_ver, :socks_user, :socks_pass
#      attr_reader :exception, :warning
      alias open new
      def Config(socks_addr, socks_port = 1080, socks_ver = 5, socks_user = nil, socks_pass = nil)
        return self unless socks_addr
        newclass = Class.new(self)
        newclass.module_eval {
          @socks_addr = socks_addr
          @socks_port = socks_port
          @socks_ver = socks_ver
          @socks_user = socks_user
          @socks_pass = socks_pass
#         @exception = nil
#         @warning   = nil
        }
        newclass
      end
      def D(msg)
        return unless $DEBUG
        warn msg
      end
    end

    def initialize(host, service)
      socks_ver, socks_addr, socks_port = 5,*($_.split(':')) if 
        !self.class.socks_addr && ( $_=ENV['SOCKS_SERVER'] || $_=ENV['SOCKS5_SERVER'] )
#      socks_ver, socks_addr, socks_port = 4,*$_.split(':') if !self.class.socks_addr && $_=ENV['SOCKS4_SERVER']
#      socks_ver, socks_addr, socks_port = 5,*$_.split(':') if !self.class.socks_addr && $_=ENV['SOCKS5_SERVER']
      socks_ver = $_ if !self.class.socks_ver && $_=ENV['SOCKS_VERSION']
      socks_user = $_ if !self.class.socks_user && $_=ENV['SOCKS_USER']
      socks_pass = $_ if !self.class.socks_pass && ( $_=ENV['SOCKS_PASSWORD'] || $_=ENV['SOCKS_PASSWD'] )
      socks_ver, socks_addr, socks_port = 
        self.class.socks_ver, self.class.socks_addr, self.class.socks_port if self.class.socks_addr
      socks_port ||= 1080
      if socks_addr
#        D "opening SOCKS#{socks_ver} connection to #{socks_addr}:#{socks_port}..."
        host = Socket.gethostbyname(host)[3]
        socks_atyp = (host.length > 4 ? 0x4 : 0x1)
        begin
          super(socks_addr,socks_port)
          auth_method = socks_user ? [0x2,0x0] : [0x0]
          write( [socks_ver,auth_method.size,*auth_method].pack('C*') )
        rescue Exception
          close
          raise SOCKSSocketError, 'Cannot connect SOCKS server.'
        end

        ver, method = ($_=read(2)).unpack('C*')
        raise SOCKSSocketError, 'SOCKS version is mismatched' unless ver == socks_ver
        raise SOCKSSocketError, 'No acceptable methods' if method == 0xff

        if method==0x2
            write( [0x1,socks_user.length,socks_user,socks_pass.length,socks_pass].pack('CCA*CA*') )
            ver, status  = ($_=read(2)).unpack('C*')
            if status != 0
              close
              raise SOCKSSocketError, 'Username/Password authentication failure.'
            end
        end
        if method == 0xff
          close
          raise SOCKSSocketError, 'No acceptable methods.'
        end

        write( [socks_ver,0x1,0x0,socks_atyp,host,Socket.getservbyname(service.to_s)].pack('CCCCA*n') )
        ver, reply  = ($_=read(2)).unpack('C*')
        case reply
          when 0
            # succeeded
          when 1
            close
            raise SOCKSSocketError, 'General SOCKS server failure.'
          when 2
            close
            raise SOCKSSocketError, 'Connection not allowed by ruleset.'
          when 3
            close
            raise SOCKSSocketError, 'Network unreachable.'
          when 4
            close
            raise SOCKSSocketError, 'Host unreachable.'
          when 5
            close
            raise SOCKSSocketError, 'Connection refused.'
#            raise Errno::ECONNREFUSED, 'Connection refused.'
          when 6
            close
            raise SOCKSSocketError, 'TTL expired.'
          when 7
            close
            raise SOCKSSocketError, 'Command not supported.'
          when 8
            close
            raise SOCKSSocketError, 'Address type not supported.'
          else
            close
            raise SOCKSSocketError, 'Unknown reply type is returned.'
        end
        rsv ,atyp  = ($_=read(2)).unpack('C*')
        case atyp
          when 1
            bnd_addr = read(4).unpack('C*').join('.')
          when 3
            bnd_addr = read(getc)
          when 4
            bnd_addr = read(16).unpack('C*').join('.')
          else
            raise SOCKSSocketError, 'Unknown address type is returned.'
        end
        bnd_port = read(2).unpack('n')
      else
        super
      end
    end
  end
end # Net
