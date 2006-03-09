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

    class AddDictionaryDialog < GladeBase 
        include GetText
        GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

        MAX_TV = 30
        MAX_CB = 18

        NAME = 0
        DESC = 1

        def initialize(parent, dicname=nil, hash=nil, &callback_proc)
            super("add_dictionary_dialog.glade")
            @dialog.transient_for = parent
            @prefs = Preferences.instance
            @dicname = dicname
            @hash = hash
            @callback_proc = callback_proc
            initialize_ui
        end

        def on_add

            checks = [
                @name_entry.text.empty?,
                @server_entry.text.empty?,
                @port_entry.text.empty?,

                (@sel_db_radiobutton.active? and
                !@sel_db_treeview.has_row_selected?),

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

            hash = {}

            hash[:server] = @server_entry.text
            hash[:port] = @port_entry.text
            hash[:all_dbs] = @all_db_radiobutton.active?

            hash[:sel_dbs] = @sel_db_treeview.selected_iters.collect do |iter|
                iter[NAME]    
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
            @sel_db_sw.sensitive = @sel_db_radiobutton.active?
        end

        def on_serv_auth_toggled
            @serv_auth_table.sensitive = @serv_auth_checkbutton.active?
        end

        def on_server_activate
            update_lists
        end

        private

        def close!
            @thread.kill if @thread.alive?
            @dialog.destroy unless @dialog.destroyed?
        end

        def update_lists
            @sel_db_treeview.model.clear
            @sel_strat_combobox.model.clear

            @last_server = @server_entry.text
            @last_port = @port_entry.text

            begin
                dict = DICTClient.new(@server_entry.text, @port_entry.text,
                                      $DEBUG)

                dbs = dict.show_db
                dbs.keys.sort.each do |name|
                    row = @sel_db_treeview.model.append

                    row[NAME] = name
                    row[DESC] = dbs[name]
                end

                dict.show_strat.each do |name, desc|
                    row = @sel_strat_combobox.model.append

                    name = name.utf8_slice(0..MAX_CB) + "..." \
                        if name.utf8_length > MAX_CB
                    desc = desc.utf8_slice(0..MAX_CB) + "..." \
                        if desc.utf8_length > MAX_CB

                    row[NAME] = name
                    row[DESC] = desc
                end
                @sel_strat_combobox.active = 0

                dict.disconnect
            rescue => e
                $stderr.puts e
            end
        end

        def start_update_lists_thread
            @last_server ||= ""
            @last_port ||= ""

            @thread = Thread.new do
                while true
                    if !@server_entry.has_focus?
                        if @last_server != @server_entry.text
                            update_lists
                        end
                    elsif !@port_entry.has_focus?
                        if @last_port != @port_entry.text
                            update_lists
                        end
                    end

                    sleep 0.8
                end
            end
        end

        def set_initial_data
            # Main fields
            @name_entry.text = @dicname
            @server_entry.text = @hash[:server]
            @port_entry.text = @hash[:port]

            
            Thread.new do
                update_lists

                # Selected dbs
                if !@hash[:all_dbs]
                    @sel_db_radiobutton.active = true
                    @sel_db_treeview.model.each do |model, path, iter|
                        @sel_db_treeview.selection.select_iter(iter) \
                            if @hash[:sel_dbs].include? iter[NAME]
                    end
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
            end

            # Auth
            if @hash[:auth]
                @serv_auth_checkbutton.active = true
                @login_entry.text = @hash[:login]
                @password_entry.text = @hash[:password]
            end
        end

        def initialize_ui
            @dialog.signal_connect("delete-event") do
                close!
            end

            @sel_db_treeview.model = Gtk::ListStore.new(String, String)
            @sel_db_treeview.selection.mode = Gtk::SELECTION_MULTIPLE

            @sel_strat_combobox.model = Gtk::ListStore.new(String, String)
            renderer = Gtk::CellRendererText.new
            @sel_strat_combobox.pack_start(renderer, true)
            @sel_strat_combobox.set_attributes(renderer, :text => NAME)

            @server_entry.text = "dict.org"
            @port_entry.text = DICTClient::DEFAULT_PORT.to_s

            renderer = Gtk::CellRendererText.new
            col = Gtk::TreeViewColumn.new("Name", renderer, :text => NAME)
            @sel_db_treeview.append_column(col)

            renderer = Gtk::CellRendererText.new
            col = Gtk::TreeViewColumn.new("Description", renderer,
                                          :text => DESC)
            @sel_db_treeview.append_column(col)

            if !@hash.nil? and !@dicname.nil?
                set_initial_data
            end

            start_update_lists_thread
        end
    end
        
end
end
