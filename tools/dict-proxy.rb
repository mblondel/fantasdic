#!/usr/bin/ruby
#
# DICT, over HTTP, proxy
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

require 'socket'
require 'net/http'
require 'uri'

class DictProxy

    APPNAME = 'dict-proxy'
    APPVERSION = '0.1'
    DEFAULT_PORT = '2628'

    def initialize(proxyhost, proxyport, url, targethost, targetport)
        @host = proxyhost
        server = TCPServer.new(proxyhost, proxyport)
        url = URI.parse(url)

        proxy = ENV['http_proxy']

        unless proxy.nil?
            proxy = URI.parse(proxy)
            proxy_host = proxy.host
            proxy_port = proxy.port
        end

        while true
            Thread.new(server.accept) do |session|
                begin
                    init_connection(session)
                    while msg = session.readline("\r\n")
                        puts "RECV: #{msg}" if $DEBUG

                        req = Net::HTTP::Post.new(url.path)

                        req.set_form_data({'targethost' => targethost,
                                                 'targetport' => targetport,
                                                 'command' => msg})

                        if proxy.nil?
                            net_http = Net::HTTP.new(url.host, url.port)
                        else
                            net_http = Net::HTTP.new(url.host, url.port,
                                                     proxy_host, proxy_port)
                        end

                        res = net_http.start { |http| http.request(req) }

                        session.print res.body

                    end
                rescue IOError, Errno::ECONNRESET
                    puts "Connection closed by client" if $DEBUG
                end
            end
        end

    end

    def init_connection(session)
        send_line(session, "220 #{@host} #{APPNAME} (version #{APPVERSION})" +
                          " <nothing> <123456789@#{@host}>")
    end

    def send_line(session, line)
        session.print(line + "\r\n")
        puts "SEND: #{line}" if $DEBUG
    end

end

class HttpBridge

    def initialize
        require 'cgi'

        print "Content-type: text/plain\r\n\r\n"
        post = CGI.new

        sock = TCPSocket.open(post['targethost'], post['targetport'])
        welcome = line = sock.readline("\r\n")
        sock.print(post['command'].chomp + "\r\n")

        while line = sock.readline("\r\n")
            print line
            break if error_response? line or ok_response? line
        end

        sock.close
    end

    def error_response?(response)
        response =~ /^[45]/
    end

    def ok_response?(response)
        response =~ /^250/
    end

end

def usage
    puts ""
    puts "Usage"
    puts ""
    puts "This programs needs to be executed with the --server option "
    puts "on the local machine as well as be put on an HTTP server."
    puts ""
    puts "ruby dict-proxy.rb --server proxyhost proxyport " + \
         "url targethost targetport"
    puts ""
    puts "\tRuns the DICT, over HTTP, proxy server"
    puts ""
    puts "ruby dict-proxy.rb --htaccess"
    puts ""
    puts "\tGenerates a suitable .htaccess file to run this program on Apache."
    puts ""
end

def set_htaccess
    htaccess = <<EOS
DirectoryIndex index.rb
Options +ExecCGI
AddHandler cgi-script .rb
EOS

    File.open('.htaccess', 'w') do |f|
        f.puts htaccess
    end
end

if __FILE__ == $0
    if ARGV.length == 6 and ARGV[0] == '--server'
        DictProxy.new(ARGV[1], ARGV[2], ARGV[3], ARGV[4], ARGV[5])
    elsif ARGV.length == 1 and ARGV[0] == '--htaccess'
        set_htaccess
    elsif ARGV.length > 0
        usage
    else
        HttpBridge.new
    end
end