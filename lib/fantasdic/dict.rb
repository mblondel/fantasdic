# Fantasdic
# Copyright (C) 2006 Mathieu Blondel
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# Based upon Ruby/DICT by Ian Macdonald <ian@caliban.org>

require 'socket'
require 'md5'

class DICTClient

    DATABASES_PRESENT = '110'
    STRATEGIES_AVAILABLE = '111'
    DATABASE_INFORMATION = '112'
    HELP_TEXT = '113'
    SERVER_INFORMATION = '114'
    CHALLENGE_FOLLOWS = '130'
    DEFINITIONS_RETRIEVED = '150'
    WORD_DEFINITION = '151'
    MATCHES_PRESENT = '152'
    STATUS_RESPONSE = '210'
    CONNECTION_ESTABLISHED = '220'
    CLOSING_CONNECTION = '221'
    AUTHENTICATION_SUCCESSFUL = '230'
    OK = '250'
    SEND_RESPONSE = '330'
    TEMPORARILY_UNAVAILABLE = '420'
    SHUTTING_DOWN = '421'
    UNRECOGNISED_COMMAND = '500'
    ILLEGAL_PARAMETERS = '501'
    COMMAND_NOT_IMPLEMENTED = '502'
    PARAMETER_NOT_IMPLEMENTED = '503'
    ACCESS_DENIED = '530'
    AUTH_DENIED = '531'
    UNKNOWN_MECHANISM = '532'
    INVALID_DATABASE = '550'
    INVALID_STRATEGY = '551'
    NO_MATCH = '552'
    NO_DATABASE_PRESENT = '554'
    NO_STRATEGY_AVAILABLE = '555'

    ALL_DATABASES = '*'
    DEFAULT_MATCH_STRATEGY = '.'

    DEFAULT_PORT = 2628

    class ConnectionError < RuntimeError
    end

    class ConnectionLost < RuntimeError
    end

    class Definition < Struct.new(:word, :body, :database, :description)
    end

    class Cache < Struct.new(:key, :value)
        include Comparable

        def <=>(cache)
            self.key <=> cache.key
        end
    end

    KEEP_CONNECTION_MAX_TIME = 60

    # Class methods
    
    # Connections are held for sometime so that it's faster to lookup words
    @@connections = {}

    def self.close_long_connections
        @@connections.each do |key, connection|
            if Time.now - connection.last_time > KEEP_CONNECTION_MAX_TIME
                connection.disconnect
            end
        end
    end

    def self.close_all_connections
        @@connections.each do |key, connection|
            begin
                connection.disconnect
            rescue
            end
        end
    end

    def self.close_active_connection
        @@current_connection.disconnect
    end

    def self.get_connection(server, port, login="", password="",
                            app_name=Fantasdic::TITLE)
        unless @@connections.has_key? [server, port]
            @@connections[[server,port]] = DICTClient.new(server, port, $DEBUG)
            @@connections[[server,port]].client(app_name)

            unless login.empty? or infos[:password].empty?
                @@connections[[server,port]].auth(login, password)
            end
        end
        @@current_connection = @@connections[[server,port]]
        @@connections[[server,port]]
    end

    attr_reader :capabilities, :msgid, :host, :port, :last_time

    def initialize(host, port = DEFAULT_PORT, debug = false)
        @host = host
        @port = port
        @debug = debug

        begin
            @sock = TCPSocket.open(host, port)
        rescue => e
            raise ConnectionError, e.to_s
        end

        response = get_response
        raise ConnectionError, response if error_response? response

        caps, @msgid = /<(.+?)>\s(<.+>)/.match(response)[1..2]
        @capabilities = caps.split(/\./)

        if @debug
            printf("Capabilities: %s\n", @capabilities.join(', '))
            printf("Msgid: %s\n", @msgid)
        end

        @cache_queue = []
       
        @@connections[[@host, @port]] = self
        @last_time = Time.now      
    end

    private

    def error_response?(response)
        response =~ /^[45]/
    end

    def matches_present_response?(response)
        response =~ /^#{MATCHES_PRESENT}/
    end

    def ok_response?(response)
        response =~ /^#{OK}/
    end

    def word_def_response?(response)
        response =~ /^#{WORD_DEFINITION}/
    end

    def end_of_msg?(line)
        line =~ /^\.\r$/ ? true : false
    end

    def get_line
        begin
            response = @sock.readline("\r\n")
        rescue EOFError
            raise ConnectionLost    
        end
        $stderr.printf("RECV: %s", response) if @debug
        response
    end

    alias :get_response :get_line

    def send_line(line)
        linern = line + "\r\n"
        $stderr.printf("SEND: %s", linern) if @debug
        @sock.print(linern)
    end

    def exec_cmd(command)
        send_line(command)
        response = get_response
        @last_time = Time.now
        code, msg = /^(\d\d\d)\s(.*)$/.match(response)[1..2]
    end

    def has_pair?(line)
        line =~ /^(\S+)\s"(.+)"\r$/
    end

    def get_pair(line)
        key, value = /^(\S+)\s"(.+)"\r$/.match(line)[1..2]
    end

    def get_pairs
        array = Array.new
        while line = get_line
            return array if ok_response? line
            array << get_pair(line) if has_pair? line
        end
    end

    def get_hash_key_value(array_pairs)
        hash = Hash.new
        array_pairs.each do |key, value|
            hash[key] = value    
        end
        hash
    end

    def get_hash_key_array_values(array_pairs)
        hash = Hash.new
        array_pairs.each do |key, value|
            hash[key] ||= []
            hash[key] << value
        end
        hash
    end

    def get_msg
        msg = ""
        while line = get_line
            return msg if ok_response? line
            msg << line
        end
    end

    MAX_CACHE = 30

    def update_cache(cache)
        @cache_queue.unshift(cache)

        if @cache_queue.length > MAX_CACHE
            @cache_queue.pop
        end
    end

    public

    # Instance methods

    def disconnect
        begin
        exec_cmd('QUIT')        
            @sock.close
        rescue ConnectionLost
            # connection already closed by server
        end
        @@connections.delete([@host, @port])
    end

    def define(db, word)
        definitions = Array.new
    
        df = Definition.new
        df.body = ''

        resp_code, resp_msg = exec_cmd('DEFINE %s "%s"' % [ db, word ])

        if error_response? resp_code or matches_present_response? resp_code
            return [] 
        end

        while line = get_line
            return definitions if ok_response? line

            if word_def_response? line
                df.word, df.database, df.description = \
                /^\d\d\d\s"(.+?)"\s(\S+)\s"(.+)"(.*)\r$/.match(line)[1..3]
            elsif end_of_msg? line
                definitions << df
                df = Definition.new
                df.body = ''
            else
                df.body << line
            end
        end
    end

    def multiple_define(dbs, word)
        definitions = []
        dbs.each do |db|
            definitions += define(db, word)
        end
        definitions
    end

    def cached_multiple_define(dbs, word)
        cache = Cache.new
        cache.key = [dbs, word]

        i = @cache_queue.index(cache)
        if i.nil?
            res = multiple_define(dbs, word)
            cache.value = res
            update_cache(cache)
            res
        else            
            @cache_queue[i].value
        end
    end

    def match(db, strategy, word)
        code, msg = exec_cmd('MATCH %s %s "%s"' % [ db, strategy, word])
        if error_response? code
            {}
        else
            get_hash_key_array_values(get_pairs)
        end
    end

    def multiple_match(dbs, strategy, word)
        matches = {}
        dbs.each do |db|
            m = match(db, strategy, word)
            m.each_key do |found_db|   
                matches[found_db] = m[found_db]
            end
        end        
        matches
    end

    def cached_multiple_match(dbs, strategy, word)
        cache = Cache.new
        cache.key = [dbs, strategy, word]

        i = @cache_queue.index(cache)
        if i.nil?
            res = multiple_match(dbs, strategy, word)
            cache.value = res
            update_cache(cache)
            res
        else
            @cache_queue[i].value
        end
    end

    def show_db
        exec_cmd('SHOW DB')
        get_hash_key_value(get_pairs)
    end

    def show_strat
        exec_cmd('SHOW STRAT')
        get_hash_key_value(get_pairs)
    end

    def show_info(db)
        exec_cmd('SHOW INFO %s' % db)
        get_msg
    end

    def show_server
        exec_cmd('SHOW SERVER')
        get_msg
    end

    def status
        code_resp, resp_msg = exec_cmd('STATUS')
        resp_msg
    end

    def help
      exec_cmd('HELP')
      get_msg
    end

    def client(info)
        exec_cmd('CLIENT %s' % info)
    end

    def auth(user, secret)
        auth = MD5::new(@msgid + secret).hexdigest
        exec_cmd('AUTH %s %s' % [ user, auth ])
    end
end

if __FILE__ == $0
    require 'pp' # pretty print
    dict = DICTClient.new('localhost', DICTClient::DEFAULT_PORT, true)
    dict.client('Fantasdic')
    pp dict.show_db
    pp dict.show_strat
    pp dict.match('gcide', 'lev', 'test')
    pp dict.define('gcide', 'test')
    dict.disconnect
end

