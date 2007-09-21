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

module Fantasdic
module UI

    class ServerInfosDialog < GladeBase 
        include GetText
        GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize
            super("server_infos_dialog.glade")
        end

        def on_close
            @server_infos_dialog.hide
        end

        def text
            @server_infos_textview.buffer.text
        end

        def text=(txt)
            @server_infos_textview.buffer.text = txt
        end

        def title
            @server_infos_dialog.title
        end

        def title=(str)
            @server_infos_dialog.title = str
        end
    end

    class AddDictionaryDialog < GladeBase 
        include GetText
        GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

        MAX_TV = 30
        MAX_CB = 18

        NAME = 0
        DESC = 1

        PAGE_GENERAL_INFORMATIONS = 0
        PAGE_DATABASES = 1

        def initialize(parent, dicname=nil, hash=nil, &callback_proc)
            super("add_dictionary_dialog.glade")
            @dialog.transient_for = parent
            @prefs = Preferences.instance
            @dicname = dicname
            @hash = hash
            @threads = []
            @callback_proc = callback_proc
            initialize_ui
            initialize_signals
        end

        private

        def sel_dbs_have?(name)
            ret = false
            @sel_db_treeview.model.each do |model, path, iter|
                ret = true if iter[NAME] == name
            end
            ret
        end

        def status_bar_msg=(message)
            @statusbar.push(0, message)
        end

        def close!
            @threads.each { |t| if t.alive?; t.kill; t.join; end }
            @dialog.hide
        end

        def sensitize_move_up
            @move_up_button.sensitive = @sel_db_treeview.has_row_selected?     
        end

        def sensitize_move_down
            @move_down_button.sensitive = \
                @avail_db_treeview.has_row_selected?
        end

        def update_lists
            @general_infos_vbox.sensitive = false
            @databases_vbox.sensitive = false
            @add_button.sensitive = false

            self.status_bar_msg = _("Fetching informations from %s...") \
                                  % @server_entry.text

            @avail_db_treeview.model.clear
            @sel_db_treeview.model.clear            

            @last_server = @server_entry.text
            @last_port = @port_entry.text

            begin
                dict = DICTClient.new(@server_entry.text, @port_entry.text,
                                      $DEBUG)

                if @serv_auth_checkbutton.active?
                    unless @login_entry.text.empty? or \
                           @password_entry.text.empty?

                        dict.auth(@login_entry.text, @password_entry.text)
                    end
                end

                sel_db_desc = {}

                dbs = dict.show_db

                # Add available databases
                dbs.keys.sort.each do |name|
                    row = @avail_db_treeview.model.append

                    row[NAME] = name
                    row[DESC] = dbs[name]

                    if !@hash.nil? and !@hash[:sel_dbs].nil? and \
                        @hash[:sel_dbs].include? name
                        sel_db_desc[name] = row[DESC]
                    end
                end

                # Add selected databases
                if !@hash.nil? and !@hash[:sel_dbs].nil? and \
                    @hash[:server] == @server_entry.text
                    @hash[:sel_dbs].each do |name|
                        row = @sel_db_treeview.model.append
    
                        row[NAME] = name
                        row[DESC] = sel_db_desc[name]
                    end
                end

                @avail_strats = dict.show_strat.collect { |s| s[0] }

                dict.disconnect
                self.status_bar_msg = ""
                @add_button.sensitive = true
            rescue DICTClient::ConnectionError
                self.status_bar_msg = _("Could not connect to %s") \
                                      % @server_entry.text
                @add_button.sensitive = false
            end

            @general_infos_vbox.sensitive = true
            @databases_vbox.sensitive = true
        end

        def set_initial_data
            # Main fields
            @name_entry.text = @dicname
            @server_entry.text = @hash[:server]
            @port_entry.text = @hash[:port]

            # Font buttons
            @print_fontbutton.font_name = @hash[:print_font_name] \
                if @hash[:print_font_name]
            @results_fontbutton.font_name = @hash[:results_font_name] \
                if @hash[:results_font_name]
            
            @threads << Thread.new do
                update_lists

                # Selected dbs
                if !@hash[:all_dbs]
                    @sel_db_radiobutton.active = true
                end

                # Auth
                @serv_auth_checkbutton.active = @hash[:auth]
                @login_entry.text = @hash[:login] if @hash[:login]
                @password_entry.text = @hash[:password] if @hash[:password]
            end
        end

        def show_db_infos(dbname)
            if @server_entry.text.empty?
                ErrorDialog.new(@dialog, _("Server missing"))
                return false
            end
                
            if @server_entry.text.empty?
                ErrorDialog.new(@dialog, _("Port missing"))
                return false
            end                

            begin
                dict = DICTClient.new(@server_entry.text, @port_entry.text,     
                                     $DEBUG)

                if @serv_auth_checkbutton.active?
                    unless @login_entry.text.empty? or \
                           @password_entry.text.empty?

                        dict.auth(@login_entry.text, @password_entry.text)
                    end
                end

                window = ServerInfosDialog.new
                window.title = _("About database %s") % dbname
                window.text = dict.show_info(dbname)

                dict.disconnect
            rescue DICTClient::ConnectionError
                self.status_bar_msg = _("Could not connect to %s") \
                                      % @server_entry.text
            end
        end

        def initialize_signals
            initialize_dialog_buttons_signals
            initialize_dictionaries_signals
        end

        def initialize_dictionaries_signals
            @server_entry.signal_connect("activate") do
                @port_entry.grab_focus
            end

            @port_entry.signal_connect("activate") do
                @server_entry.grab_focus
            end

            @login_entry.signal_connect("activate") do
                @server_entry.activate
            end

            @password_entry.signal_connect("activate") do
                @server_entry.activate
            end

            @move_up_button.signal_connect("clicked") do
                iters = []
                @sel_db_treeview.selection.selected_each do |model, path, iter|
                    iters << iter
                end
                iters.each { |iter| @sel_db_treeview.model.remove(iter) }
                @avail_db_treeview.selection.unselect_all

                @all_db_radiobutton.activate if @sel_db_treeview.model.empty?
            end

            @move_down_button.signal_connect("clicked") do
                @avail_db_treeview.selection.selected_each do |model,
                                                               path,
                                                               iter|
                    unless sel_dbs_have? iter[NAME]
                        row = @sel_db_treeview.model.append
        
                        row[NAME] = iter[NAME]
                        row[DESC] = iter[DESC]
                    end
                end
                @avail_db_treeview.selection.unselect_all

                @sel_db_radiobutton.activate
            end

            @server_infos_button.signal_connect("clicked") do
                if @server_entry.text.empty?
                    ErrorDialog.new(@dialog, _("Server missing"))
                    return false
                end
                    
                if @server_entry.text.empty?
                    ErrorDialog.new(@dialog, _("Port missing"))
                    return false
                end                

                begin
                    dict = DICTClient.new(@server_entry.text,
                                          @port_entry.text,
                                          $DEBUG)

                    if @serv_auth_checkbutton.active?
                        unless @login_entry.text.empty? or \
                            @password_entry.text.empty?

                            dict.auth(@login_entry.text, @password_entry.text)
                        end
                    end

                    ServerInfosDialog.new.text = dict.show_server

                    dict.disconnect
                rescue DICTClient::ConnectionError
                    self.status_bar_msg = _("Could not connect to %s") \
                                        % @server_entry.text
                end
            end # show server infos
        end

        def initialize_dialog_buttons_signals
            @show_help_button.signal_connect("clicked") do
                Browser::open_help("fantasdic-dictionaries")
            end

            @cancel_button.signal_connect("clicked") do
                close!
            end

            @serv_auth_checkbutton.signal_connect("toggled") do
                @serv_auth_table.sensitive = @serv_auth_checkbutton.active?
                @threads << Thread.new do
                    update_lists
                end
            end

            @add_button.signal_connect("clicked") do
                checks = [
                    @name_entry.text.empty?,
                    @server_entry.text.empty?,
                    @port_entry.text.empty?,

                    (@sel_db_radiobutton.active? and
                    @sel_db_treeview.model.empty?),

                    (@serv_auth_checkbutton.active? and
                    @password_entry.text.empty? and
                    @login_entry.text.empty?)
                ]

                checks.each do |expr|
                    if expr == true
                        ErrorDialog.new(@dialog, _("Fields missing")) 
                        return false
                    end
                end

                if @prefs.dictionary_exists? @name_entry.text and \
                   !@update_dialog

                    ErrorDialog.new(@dialog,
                                    _("Dictionary %s exists already!") % \
                                        @name_entry.text) 
                    return false    
                end

                hash = {}

                hash[:server] = @server_entry.text
                hash[:port] = @port_entry.text
                hash[:all_dbs] = @all_db_radiobutton.active?

                hash[:sel_dbs] = []
                @sel_db_treeview.model.each do |model, path, iter|
                    hash[:sel_dbs] << iter[NAME]
                end

                hash[:avail_strats] = @avail_strats
                hash[:sel_strat] = "define" # default strat

                hash[:auth] = @serv_auth_checkbutton.active?
                hash[:login] = @login_entry.text
                hash[:password] = @password_entry.text

        
                hash[:results_font_name] = @results_fontbutton.font_name
                hash[:print_font_name] = @print_fontbutton.font_name

                @callback_proc.call(@name_entry.text, hash)

                close!
            end # add_button signal
        end

        def initialize_ui
            @dialog.signal_connect("delete-event") do
                close!
            end

            @print_vbox.visible = Fantasdic::UI::HAVE_PRINT

            @avail_db_treeview.model = Gtk::ListStore.new(String, String)
            @avail_db_treeview.selection.mode = Gtk::SELECTION_MULTIPLE

            @avail_db_treeview.selection.signal_connect("changed") do
                sensitize_move_down
            end

            @sel_db_treeview.model = Gtk::ListStore.new(String, String)
            @sel_db_treeview.selection.mode = Gtk::SELECTION_MULTIPLE

            @sel_db_treeview.selection.signal_connect("changed") do
                sensitize_move_up
            end

            @server_entry.text = "dict.org"
            @port_entry.text = DICTClient::DEFAULT_PORT.to_s

            @last_server = @server_entry.text
            @last_port = @port_entry.text
            @last_login = @login_entry.text
            @last_password = @password_entry.text
            
            [[@server_entry, @last_server], 
             [@port_entry, @last_port],
             [@login_entry, @last_login],
             [@password_entry, @last_login]].each do |entry, last|
                entry.signal_connect("focus-out-event") do |w, event|
                    if last != entry.text
                        last = entry.text
                        @threads << Thread.new do
                            update_lists
                        end
                    end
                    false
                end
            end


            [@avail_db_treeview, @sel_db_treeview].each do |tv|
                # Double click on row: show db infos
                tv.signal_connect("row-activated") do |view, path, column|
                    iter = tv.model.get_iter(path)
                    dbname = iter[NAME]
                    show_db_infos(dbname)
                end

                # Renderer which slice too long names
                renderer = Gtk::CellRendererText.new
                col = Gtk::TreeViewColumn.new("Database", renderer)
                
                col.set_cell_data_func(renderer) do |col, renderer, model, iter|
                    str = "%s (%s)" % [iter[NAME], iter[DESC]]
                    str = str.utf8_slice(0..40) + "..." \
                            if str.utf8_length > 50
                    renderer.text = str
                end
                tv.append_column(col)
            end

            if !@hash.nil? and !@dicname.nil?
                @update_dialog = true
                set_initial_data
            else
                @threads << Thread.new do
                    update_lists
                end
            end

            @dialog.show_all
        end
    end
        
end
end
