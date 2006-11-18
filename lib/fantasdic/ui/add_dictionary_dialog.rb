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
            @server_infos_dialog.destroy
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
        end

        def on_add

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

            if @prefs.dictionary_exists? @name_entry.text and !@update_dialog
                ErrorDialog.new(@dialog, _("Dictionary %s exists already!") \
                                         % @name_entry.text) 
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

            hash[:avail_strats] = []
            @sel_strat_combobox.model.each do |model, path, iter|
                hash[:avail_strats] << iter[NAME]    
            end            

            active_strat = @sel_strat_combobox.active.to_s
            active_iter = @sel_strat_combobox.model.get_iter(active_strat)
            hash[:sel_strat] = active_iter.nil? ? ' ' : active_iter[NAME]

            hash[:auth] = @serv_auth_checkbutton.active?
            hash[:login] = @login_entry.text
            hash[:password] = @password_entry.text

            @callback_proc.call(@name_entry.text, hash)

            close!
        end

        def on_cancel
            close!
        end

        def on_radiobutton_group_changed
        end

        def on_serv_auth_toggled
            @serv_auth_table.sensitive = @serv_auth_checkbutton.active?
        end

        def on_server_activate
            @port_entry.grab_focus
        end

        def on_server_infos_button_clicked
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

                ServerInfosDialog.new.text = dict.show_server

                dict.disconnect
            rescue DICTClient::ConnectionError
                self.status_bar_msg = _("Could not connect to %s") \
                                      % @server_entry.text
            end
        end

        def sel_dbs_have?(name)
            ret = false
            @sel_db_treeview.model.each do |model, path, iter|
                ret = true if iter[NAME] == name
            end
            ret
        end

        def on_move_up_button_clicked
            iters = []
            @sel_db_treeview.selection.selected_each do |model, path, iter|
                iters << iter
            end
            iters.each { |iter| @sel_db_treeview.model.remove(iter) }
            @avail_db_treeview.selection.unselect_all

            @all_db_radiobutton.activate if @sel_db_treeview.model.empty?
        end

        def on_move_down_button_clicked
            @avail_db_treeview.selection.selected_each do |model, path, iter|
                unless sel_dbs_have? iter[NAME]
                    row = @sel_db_treeview.model.append
    
                    row[NAME] = iter[NAME]
                    row[DESC] = iter[DESC]
                end
            end
            @avail_db_treeview.selection.unselect_all

            @sel_db_radiobutton.activate
        end

        private

        def status_bar_msg=(message)
            @statusbar.push(0, message)
        end

        def close!
            @threads.each { |t| t.kill if t.alive? }
            @dialog.destroy unless @dialog.destroyed?
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
            @sel_strat_combobox.model.clear

            @last_server = @server_entry.text
            @last_port = @port_entry.text

            begin
                dict = DICTClient.new(@server_entry.text, @port_entry.text,
                                      $DEBUG)

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

                # Add strats
                dict.show_strat.each do |name, desc|
                    row = @sel_strat_combobox.model.append

                    row[NAME] = name
                    row[DESC] = desc
                end
                @sel_strat_combobox.active = 0

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

            
            @threads << Thread.new do
                update_lists

                # Selected dbs
                if !@hash[:all_dbs]
                    @sel_db_radiobutton.active = true
                end

                # Selected strategy
                n = 0
                @sel_strat_combobox.model.each do |model, path, iter|
                    if iter[NAME] == @hash[:sel_strat]
                        @sel_strat_combobox.active = n
                        break
                    end
                    n += 1
                end

                # Auth
                if @hash[:auth]
                    @serv_auth_checkbutton.active = true
                    @login_entry.text = @hash[:login]
                    @password_entry.text = @hash[:password]
                end

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

                window = ServerInfosDialog.new
                window.title = _("About database %s") % dbname
                window.text = dict.show_info(dbname)

                dict.disconnect
            rescue DICTClient::ConnectionError
                self.status_bar_msg = _("Could not connect to %s") \
                                      % @server_entry.text
            end
        end

        def initialize_ui
            @dialog.signal_connect("delete-event") do
                close!
            end

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

            @sel_strat_combobox.model = Gtk::ListStore.new(String, String)
            renderer = Gtk::CellRendererText.new
            @sel_strat_combobox.pack_start(renderer, true)
            @sel_strat_combobox.set_attributes(renderer, :text => DESC)

            @server_entry.text = "dict.org"
            @port_entry.text = DICTClient::DEFAULT_PORT.to_s

            @last_server = @server_entry.text
            @last_port = @port_entry.text
            
            [[@server_entry, @last_server], 
             [@port_entry, @last_port]].each do |entry, last|
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

        end
    end
        
end
end
