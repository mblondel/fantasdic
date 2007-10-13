# Basic extendable DICT server
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

$KCODE = "u"

require 'socket'
require 'yaml'

class Database
    def self.show_strats
        # A list of stragegies shared by all classes and their description
        [
            ['exact', 'Match headwords exactly'],
            ['prefix', 'Match prefixes']
        ]
    end

    def initialize(params)
        @params = params
    end

    def define(term)
        []
    end

    def match(strat, term)
        []
    end

end

class GrepDictionary < Database

    def define(term)
        [IO.popen("cat #{@params[:file]}" + \
                  " | grep -i \"#{term}\"").readlines.join]
    end

    def avail_strats
        ['exact']
    end

end

class DictServer

    APPNAME = 'dict-server'
    APPVERSION = '0.1'

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

    CODE_MSG = {
        '110' => '%d databases present: list follows',
        '111' => '%d strategies available: list follows',
        '112' => 'database information follows',
        '113' => 'help text follows',
        '114' => 'server information follows',
        '150' => '%d definitions found: list follows',
        '151' => '"%s" %s "%s" : definition text follows',
        '152' => '%s matches found: list follows',
        '210' => 'status',
        '250' => 'Command complete',
        '420' => 'Server temporarily unavailable',
        '421' => 'Server shutting down at operator request',
        '500' => 'Syntax Error, command not recognized',
        '501' => 'Syntax Error, illegal parameters',
        '502' => 'Command not implemented',
        '503' => 'Command parameter not implemented',
        '530' => 'Access denied',
        '531' => '',
        '532' => '',
        '550' => 'Invalid database, use "SHOW DB" for list of databases',
        '551' => 'Invalid strategy, use "SHOW STRAT" for list of strategies',
        '552' => 'No match',
        '554' => 'No database present',
        '555' => 'No strategy available'
    }

    ALL_DATABASES = '*'
    DEFAULT_MATCH_STRATEGY = '.'

    DEFAULT_PORT = 2628

    class Config

        def initialize
            @config = YAML.load(File.open('config.yaml'))
        end

        def get_db(sel_db)
            @config['databases'].each do |db|
                if db[:id] == sel_db
                    return db
                end
            end
            return nil
        end

        def method_missing(id, *args)
            method = id.id2name
            if match = /(.*)=$/.match(method)
                if args.length != 1
                    raise "Set method #{method} should be called with " +
                          "only one argument (was called with #{args.length})"
                end
                @config[match[1]] = args.first
            else
                unless args.empty?
                    raise "Get method #{method} should be called " +
                          "without argument (was called with #{args.length})"
                end
                @config[method]
            end
        end
    end

    def initialize(host, port = DEFAULT_PORT)
        @host = host
        @port = port
        @server = TCPServer.new(host, port)
        @config = Config.new

        while true
            Thread.new(@server.accept) do |session|
                init_connection(session)
                begin
                    while msg = session.readline("\r\n")
                        puts "RECV: #{msg}" if $DEBUG
    
                        case msg
                            when /^DEFINE/i
                                define(session, msg)
                            when /^MATCH/i
                                match(session, msg)
                            when /^SHOW (DB|DATABASES)/i
                                show_db(session)
                            when /^SHOW INFO/i
                                show_info(session, msg)
                            when /^SHOW (STRAT|STRATEGIES)/i
                                show_strat(session)
                            when /^SHOW SERVER/i
                                show_server(session)
                            when /^CLIENT/i
                                client(session)
                            when /^HELP/i
                                help(session)
                            when /^STATUS/i
                                status(session)
                            when /^QUIT/i
                                quit(session)
                            else
                                send_response(session, UNRECOGNISED_COMMAND)
                        end
                    end
                rescue IOError, Errno::ECONNRESET
                    puts "Connection closed by client" if $DEBUG
                end
            end
        end

    end

    private

    def send_line(session, line)
        session.print(line + "\r\n")
        puts "SEND: #{line}" if $DEBUG
    end

    def send_dot(session)
        send_line(session, '.')
    end

    def init_connection(session)
        send_line(session, "220 #{@host} #{APPNAME} (version #{APPVERSION})" +
                          " <nothing> <123456789@#{@host}>")
    end

    def send_response(session, code, *args)
        if args.empty?
            send_line(session, "#{code} #{CODE_MSG[code]}")
        else
            send_line(session, "#{code} #{CODE_MSG[code]}" % args)
        end
    end

    def remove_double_quotes(string)
        if /^"(.*)"$/i =~ string
            string = /^"(.*)"$/i.match(string)[1]
        end
        string
    end

    def define(session, line)
        line.chomp!
        if /^DEFINE (.+) (.+)$/i =~ line
            sel_db, word = /^DEFINE (.+) (.+)$/i.match(line)[1..2]
            word = remove_double_quotes(word)

            db = @config.get_db(sel_db)

            if db.nil?
                return send_response(session, INVALID_DATABASE)
            end

            klass = eval db[:class]
            dict = klass.new(db[:parameters])

            defs = dict.define(word)

            if defs.empty?
                send_response(session, NO_MATCH)
            else
                send_response(session, DEFINITIONS_RETRIEVED, defs.length)
                defs.each do |d|
                    send_response(session, WORD_DEFINITION,
                                  word, db[:id], db[:description])
                    send_line(session, d)
                    send_dot(session)
                end
                send_response(session, OK)
            end
        else
            send_response(session, ILLEGAL_PARAMETERS)
        end
    end

    def match(session, line)
        line.chomp!
        if /^MATCH (.+) (.+) (.+)$/i =~ line
            sel_db, sel_strat, word = \
                /^MATCH (.+) (.+) (.+)$/i.match(line)[1..2]

            word = remove_double_quotes(word)

            db = @config.get_db(sel_db)

            if db.nil?
                return send_response(session, INVALID_DATABASE)
            end

            klass = eval db[:class]
            dict = klass.new(db[:parameters])

            if not dict.avail_strats.include? sel_strat
                return send_response(session, INVALID_STRATEGY)
            end

            matches = dict.match(sel_strat, word)

            if matches.empty?
                send_response(session, NO_MATCH)
            else
                send_response(session, MATCHES_PRESENT, matches.length)
                matches.each do |match|
                    send_line(session, "%s \"%s\"" % [sel_db, match])
                    send_dot(session)
                end
                send_response(session, OK)
            end
        else
            send_response(session, ILLEGAL_PARAMETERS)
        end
    end

    def show_db(session)
        if @config.databases.empty?
            send_response(session, NO_DATABASE_PRESENT)
        else
            send_response(session, DATABASES_PRESENT, @config.databases.length)
            @config.databases.each do |db|
                send_line(session, "%s \"%s\"" % [db[:id], db[:name]])
            end
            send_dot(session)
            send_response(session, OK)
        end
    end

    def show_info(session , line)
        line.chomp!
        if /^SHOW INFO (.+)$/i =~ line
            sel_db = /^SHOW INFO (.+)$/i.match(line)[1]
            sel_db = remove_double_quotes(sel_db)

            db = @config.get_db(sel_db)

            if db.nil?
                send_response(session, INVALID_DATABASE)
            else
                send_response(session, DATABASE_INFORMATION)
                send_line(session, db[:description])
                send_dot(session)
                send_response(session, OK)
                present = true
            end
        else
            send_response(session, ILLEGAL_PARAMETERS)
        end
    end

    def show_strat(session)
        strats = Database.show_strats
        send_response(session, STRATEGIES_AVAILABLE, strats.length)
        strats.each do |strat, desc|
            send_line(session, "%s \"%s\"" % [strat, desc])
        end
        send_dot(session)
        send_response(session, OK)
        #send_response(session, NO_STRATEGY_AVAILABLE)
    end

    def show_server(session)
        send_response(session, SERVER_INFORMATION)
        send_line(session,
                  "#{APPNAME} (version #{APPVERSION}) on #{`uname -a`.chomp}")
        send_dot(session)
        send_response(session, OK)
    end

    def client(session)
        send_response(session, OK)
    end

    def help(session)
        send_response(session, HELP_TEXT)

        msg = <<EOS
DEFINE database word         -- look up word in database
MATCH database strategy word -- match word in database using strategy
SHOW DB                      -- list all accessible databases
SHOW DATABASES               -- list all accessible databases
SHOW STRAT                   -- list available matching strategies
SHOW STRATEGIES              -- list available matching strategies
SHOW INFO database           -- provide information about the database
SHOW SERVER                  -- provide site-specific information
OPTION MIME                  -- use MIME headers
CLIENT info                  -- identify client to server
AUTH user string             -- provide authentication information
STATUS                       -- display timing information
HELP                         -- display this help information
QUIT                         -- terminate connection
EOS

        send_line(session, msg)
        send_dot(session)
        send_response(session, OK)
    end

    def status(session)
        send_response(session, STATUS_RESPONSE)
    end

    def quit(session)
        session.close
    end
end


def set_conf
    txt = <<TXT
---
databases:
  -
    :id: japanese
    :name: Japanese
    :description: 'Japanese Dictionary (EDICT)'
    :class: GrepDictionary
    :parameters:
        :file: '/home/mathieu/Desktop/langues/japonais/edict.utf8'
  -
    :id: chinese
    :name: Chinese
    :description: 'Chinese Dictionary (CEDICT)'
    :class: GrepDictionary
    :parameters:
        :file: '/home/mathieu/Desktop/langues/chinois/cedict_ts.u8'
TXT

    unless FileTest.exists?('config.yaml')
        File.open('config.yaml', 'w') do |f|
            f.puts txt
        end
    end

end

def usage
    puts ""
    puts "Usage"
    puts ""
    puts "ruby dict-server.rb server-host server-port"
    puts ""
end

if __FILE__ == $0
    if ARGV.length == 2
        set_conf
        DictServer.new(ARGV[0], ARGV[1])
    else
        usage
    end
end