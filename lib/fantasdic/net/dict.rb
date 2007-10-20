# Fantasdic
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

# Highly modified version of Ruby/DICT, by Ian Macdonald <ian@caliban.org>

require 'socket'
require 'md5'

class DICTClient

    KEEP_CONNECTION_MAX_TIME = 60

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

    STRATEGIES_DESC = {
        "define" => "Results match with the word exactly.",
        "prefix" => "Results match with the beginning of the word.",
        "soundex" => "Results have a similar pronunciation.",
        "regexp" => "Results match with the regular expression.",
        "word" => "Results have one word that match with the word.",
        "substring" => "Results have a portion that contains the word.",
        "lev" => "Results match with the word, using the Levenshtein " + \
                 "distance algorithm.",
        "suffix" => "Results match with the end of the word."
    }

    class ConnectionError < RuntimeError
    end

    class ConnectionLost < RuntimeError
    end

    class Definition < Struct.new(:word, :body, :database, :description)
    end

    # Class methods
    
    # Connections are held for sometime so that it's faster to lookup words
    @@connections = {}
    @@current_connection = nil

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
        @@current_connection.disconnect if @@current_connection
    end

    def self.get_connection(app_name, server, port, login="", password="")
        key = [server, port, login, password]
        unless @@connections.has_key? key
            @@connections[key] = DICTClient.new(server, port, $DEBUG)
            @@connections[key].client(app_name)

            unless login.empty? or password.empty?
                @@connections[key].auth(login, password)
            end
        end
        @@current_connection = @@connections[key]        
        @@connections[key]
    end

    attr_reader :capabilities, :msgid, :host, :port, :last_time

    def initialize(host, port = DEFAULT_PORT, debug = false)
        @host = host
        @port = port
        @debug = debug
        @login = ""
        @password = ""

        begin
            if ENV['SOCKS_SERVER']
                klass = Net::SOCKSSocket
            else
                klass = TCPSocket
            end
            @sock = klass.open(host, port)
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
        response =~ /^#{OK} ok/i
    end

    def word_def_response?(response)
        response =~ /^#{WORD_DEFINITION}/
    end

    def is_dot_line?(line)
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
        begin
            @sock.print(linern)
        rescue IOError
            raise ConnectionLost
        end
    end

    def exec_cmd(command)
        send_line(command)
        response = get_response
        @last_time = Time.now
        match = /^(\d\d\d)\s(.*)$/.match(response)
        if match
            code, msg = match[1..2]
        else
            code, msg = [UNRECOGNISED_COMMAND, 'Error']
        end
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

    public

    # Instance methods

    def disconnect
        begin
            exec_cmd('QUIT')        
            @sock.close
        rescue
            # connection already closed by server
        end
        @@connections.delete([@host, @port, @login, @password])
    end

    def define(db, word)
        definitions = Array.new
    
        resp_code, resp_msg = exec_cmd('DEFINE %s "%s"' % [ db, word ])

        if error_response? resp_code or matches_present_response? resp_code
            return [] 
        end

        df = nil

        while line = get_line
            if df and (word_def_response? line or ok_response? line)
                df.body.pop if is_dot_line? df.body.last
                df.body = df.body.join
                definitions << df
            end

            if word_def_response? line
                df = Definition.new
                df.body = []
                df.word, df.database, df.description = \
                /^\d\d\d\s"(.+?)"\s(\S+)\s"(.+)"(.*)\r$/.match(line)[1..3]
            elsif ok_response? line
                return definitions
            else
                df.body << line
            end
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

    def show_db
        code, msg = exec_cmd('SHOW DB')
        get_hash_key_value(get_pairs)
    end

    def show_strat
        code, msg = exec_cmd('SHOW STRAT')
        if error_response? code
            {}
        else
            get_hash_key_value(get_pairs)
        end
    end

    def show_info(db)
        code, msg = exec_cmd('SHOW INFO %s' % db)
        if error_response?(code)
            nil
        else
            get_msg
        end
    end

    def show_server
        code, msg = exec_cmd('SHOW SERVER')
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

    def auth(login, password)
        @login = login
        @password = password
        auth = MD5::new(@msgid + password).hexdigest
        exec_cmd('AUTH %s %s' % [ login, auth ])
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

