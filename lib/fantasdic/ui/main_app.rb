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

    module Icon
        icons_dir = File.join(Config::DATA_DIR, "icons")
        LOGO_SMALL = Gdk::Pixbuf.new(File.join(icons_dir,
                                    "fantasdic_small.png"))
    end

    class MainApp < GladeBase 
        include GetText
        GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

        MAX_CACHE = 15
        KEEP_CONNECTION_OPEN_MAX_TIME = 60

        def initialize(start_p={})
            super("main_app.glade")
            @prefs = Preferences.instance

            @connections = {}
            @connections_time = {}

            @pages_seen = []
            @current_page = 0

            @cache_data = {}
            @cache_queue = []

            @start_p = start_p

            @main_app.hide
            initialize_ui
            initialize_signals
            load_preferences
            @main_app.show

            lookup(@start_p) unless @start_p.empty?
        end

        def lookup(p)
            @global_actions["Stop"].activate \
                if @lookup_thread and @lookup_thread.alive?

            @lookup_thread = Thread.new do
                close_long_connections
    
                @current_search = p
                @search_entry.text = p[:word]
                @buf = @result_text_view.buffer
                @buf.clear
                @iter = @buf.get_iter_at_offset(0)
    
                # Make the scroll go up
                @result_sw.vadjustment.value = @result_sw.vadjustment.lower
                @result_sw.hadjustment.value = @result_sw.hadjustment.lower
    
                if @prefs.dictionaries.length == 0
                    msg = _("No dictionary configured")
                    self.status_bar_msg = msg
                    @buf.insert(@iter, msg + "\n", "header")
                    Thread.current.kill
                end
    
                if p[:dictionary]
                    self.selected_dictionary = p[:dictionary]
                else 
                    p[:dictionary] = selected_dictionary
                end
    
                self.selected_strategy = p[:strategy]
                p.delete(:strategy) if ["define", "exact"].include? p[:strategy]
    
                infos = @prefs.dictionaries_infos[p[:dictionary]]
                @global_actions["Stop"].visible = true

                begin
                    dict = get_connection(p[:dictionary])

                rescue DICTClient::ConnectionError, Errno::ECONNRESET => e
                    error = _("Can't connect to server")
                    @buf.insert(@iter, error + "\n", "header")
                    @buf.insert(@iter, e.to_s)
                    self.status_bar_msg = error
                    Thread.current.kill
                end

                @show_suggested_results = false

                # Display definitions
                unless p[:strategy]
                    definitions = define(dict, p)
                    print_definitions(definitions)

                    if definitions.empty?  
                        @show_suggested_results = true 
                    end
                end
                
                # Search with match strategy. 
                # Use default strategy if define did not give results
                if p[:strategy] or definitions.empty?
                    p[:strategy] = infos[:sel_strat] unless p.has_key? :strategy
                    matches = match(dict, p)

                    print_matches(matches)
                end
    
                # Update history and pages seen
                update_pages_seen(p)
                @history_listview.update(p)
    
                # Update cache
                update_cache(p, definitions, matches)

                @global_actions["Stop"].visible = false

            end # Thread
        end
   
        private

        def define(dict, p)
            infos = @prefs.dictionaries_infos[p[:dictionary]]

            self.status_bar_msg = _("Transferring data from %s ...") %
                                        dict.host

            if @cache_data.has_key? p
                @cache_data[p][:definitions]
            elsif !p[:database].nil?
                dict.define(p[:database], p[:word])
            elsif infos[:all_dbs] == true
                dict.define(DICTClient::ALL_DATABASES, p[:word])
            else
                definitions = []
                infos[:sel_dbs].each do |db|
                    definitions += dict.define(db, p[:word])
                end
                definitions
            end
        end

        def print_definitions(definitions)
            @buf.clear
            @iter = @buf.get_iter_at_offset(0)
            last_db = ""
            definitions.each do |d|
                if last_db != d.database
                    @buf.insert(@iter, "%s [%s]\n" %
                                    [d.description, d.database],
                            "header")
                    last_db = d.database
                else
                    @buf.insert(@iter, "__________\n", "header")
                end
                @buf.insert_with_links(@iter, d.database, d.body)
            end

            # Status bar
            if definitions.empty?
                self.status_bar_msg = _("No match found.") + " " + \
                                      _("Looking for close results...")
            else
                self.status_bar_msg = _("Matches found: %d.") %
                            definitions.length
            end
        end

        def match(dict, p)  
            infos = @prefs.dictionaries_infos[p[:dictionary]]         

            if @cache_data.has_key? p
                @cache_data[p][:matches]
            elsif infos[:all_dbs] == true
                dict.match(DICTClient::ALL_DATABASES,
                        p[:strategy],
                        p[:word])
            else
                matches = {}
                infos[:sel_dbs].each do |db|
                    m = dict.match(db,
                                p[:strategy],
                                p[:word])
                    matches[db] = m[db] unless m[db].nil?
                end
                matches
            end
        end
      
        def print_matches(matches)
            # Display matches
            @buf.clear
            @iter = @buf.get_iter_at_offset(0)

           if matches.length > 0
                nb_match = 0
                matches.each { |db, w| nb_match += w.length }

                if @show_suggested_results
                    msg = _("Suggested results.") + " "
                else
                    msg = ""
                end
                msg += _("Matches found: %d.") % nb_match
                self.status_bar_msg = msg
            else
                @buf.insert(@iter, _("No match found."), "header")
                self.status_bar_msg = _("No match found.")
            end              

            matches.each do |db, words|
                @buf.insert(@iter, db + "\n", "header")  
                @buf.insert(@iter, words.join(", "))
                # Print matches with links (but slow)    
                # i = 0
                # words.each do |w|
                #     @buf.insert_link(@iter, db, w)
                #     @buf.insert(@iter, ", ") unless i == words.length
                #     i += 1
                # end
                @buf.insert(@iter, "\n", "header")
            end
        end

        def update_cache(p, definitions, matches)
            unless @cache_data.has_key? p
                @cache_data[p] = {}
                @cache_data[p][:definitions] = definitions
                @cache_data[p][:matches] = matches
                @cache_queue.push(p)

                if @cache_queue.length > MAX_CACHE
                    last = @cache_queue.pop
                    @cache_data.delete(last)
                end
            end
        end

        def status_bar_msg=(message)
            @statusbar.push(0, message)
        end

        def scan_clipboard
            @scan_thread = Thread.new(@search_entry) do |entry|
                
                last_selection = nil
                clipboard = Gtk::Clipboard.get(Gdk::Selection::CLIPBOARD)
                clipboard.request_text do |cb, text|
                    last_selection = text
                end
                
                while true
                    clipboard.request_text do |cb, text|
                        if text != last_selection
                            unless text.nil? or text.empty?                   
                                unless text =~ /^(http|ftp|file)/
                                    last_selection = text
                                    lookup(:word => text)
                                    @main_app.show \
                                        unless @main_app.visible?
                                    @main_app.present 
                                end
                            end
                        end
                    end
                    sleep(0.8)
                end
            end
        end        

        # Preferencces

        def load_window_preferences
            if @prefs.window_maximized
                @main_app.maximize
            else
                @main_app.resize(*@prefs.window_size)
                @main_app.move(*@prefs.window_position) unless \
                    @prefs.window_position == [0,0]
            end
            
            @global_actions["Statusbar"].active = @prefs.view_statusbar
            @global_actions["Toolbar"].active = @prefs.view_toolbar
            @global_actions["History"].active = @prefs.view_history
            @sidepane.position = @prefs.sidepane_position
        end

        def load_last_searches
            @prefs.last_searches.each do |search|
                @history_listview.append_search(search)
            end
            
            unless @prefs.last_search.nil? or @prefs.lookup_at_start.nil? or \
                @prefs.lookup_at_start == false or !@start_p.empty?
                lookup(@prefs.last_search) 
            end
        end

        def load_preferences
            load_window_preferences     
            load_last_searches
        end
        
        def save_window_preferences
            @prefs.view_statusbar = @global_actions["Statusbar"].active?
            @prefs.view_toolbar = @global_actions["Toolbar"].active?
            @prefs.view_history = @global_actions["History"].active?
            @prefs.sidepane_position = @sidepane.position
            @prefs.window_maximized = @maximized
            @prefs.window_size = @main_app.size
            @prefs.window_position = @main_app.position
        end

        def save_last_searches
            @prefs.last_searches = []
            @history_listview.model.each do |model, path, iter|
                @prefs.last_searches <<
                    iter[HistoryListView::Column::SEARCH_HASH]
            end
            @prefs.last_search = @pages_seen[@current_page]
        end

        def save_preferences
            save_window_preferences
            save_last_searches
            @prefs.save!
        end

        # Strategy menu

        def update_strategy_cb
            @strategy_cb.model.clear
            infos = @prefs.dictionaries_infos[selected_dictionary]
            
            strats = ["define"]
            strats += infos[:avail_strats] unless infos[:avail_strats].nil?
            
            strats.each do |strat|
                row = @strategy_cb.model.append
                row[0] = strat
            end

            @strategy_cb.active = 0
        end

        def selected_strategy
            n = @strategy_cb.active
            @strategy_cb.model.get_iter(n.to_s)[0]
        end

        def selected_strategy=(strat)
            strat = "define" if strat.nil?
            n = 0
            @strategy_cb.model.each do |model, path, iter|
                if iter[0] == strat
                    @strategy_cb.active = n
                    break
                end
                n += 1
            end
        end

        # Dictionary menu
        def update_dictionary_cb
            @dictionary_cb.model.clear

            if @prefs.dictionaries.length >= 1
                @dictionary_cb.sensitive = true
                @prefs.dictionaries.each do |dic|
                    if @prefs.dictionaries_infos[dic][:selected] == 1
                        row = @dictionary_cb.model.append
                        row[0] = dic
                    end
                end
                @dictionary_cb.active = 0
            else
                @dictionary_cb.sensitive = false
            end
        end

        def selected_dictionary
            @prefs.dictionaries[@dictionary_cb.active]
        end

        def selected_dictionary=(dicname)
            n = 0
            @dictionary_cb.model.each do |model, path, iter|
                if iter[0] == dicname
                    @dictionary_cb.active = n
                    break
                end
                n += 1
            end
        end

        def get_connection(dicname)     
            infos = @prefs.dictionaries_infos[dicname]

            # This error is raised when a word is searched
            # through the history while the associated dictionary
            # does not exist anymore in the settings
            raise DICTClient::ConnectionError,
                 _("Dictionary \"%s\" does not exist anymore") % dicname \
                 if infos.nil?

            server = infos[:server]
            port = infos[:port]

            @current_server = server

            self.status_bar_msg = _("Waiting for %s...") % server

            unless @connections.has_key? server
                @connections[server] = DICTClient.new(server, port, $DEBUG)
                @connections[server].client(Fantasdic::TITLE)
                
                unless infos[:login].empty? or infos[:password].empty?
                    @connections[server].auth(infos[:login], infos[:password]) 
                end

                @connections_time[server] = Time.now
            end
            @connections[server]
        end

        def close_connection(server)
            begin
                @connections[server].disconnect if @connections[server]
            rescue DICTClient::ConnectionLost
                # connection closed by server
            end
            @connections.delete(server)
            @connections_time.delete(server)
        end

        def close_long_connections
            @connections.each do |server, connection|
                if @connections_time[server].nil? or \
                   Time.now - @connections_time[server] \
                   > KEEP_CONNECTION_OPEN_MAX_TIME
                    close_connection(server)
                end
            end
        end

        def dictionary_menu(word)
            menu = Gtk::Menu.new
            @dictionary_cb.model.each do |model, path, iter|
                name = iter[0]              
                item = Gtk::MenuItem.new(_("Search %s" % name))
                item.signal_connect("activate") do
                    lookup(:word => word, :dictionary => name)
                end
                menu.append(item)
            end
            menu.append(Gtk::SeparatorMenuItem.new)
            item = Gtk::ImageMenuItem.new(Gtk::Stock::COPY)
            item.signal_connect("activate") do |mitem|
                Gtk::Clipboard.get(Gdk::Selection::CLIPBOARD).set_text(word)
            end
            menu.append(item)
            item = Gtk::ImageMenuItem.new(_("Select _All"))
            item.signal_connect("activate") do |mitem|
                @global_actions["SelectAll"].activate
            end
            menu.append(item)
            menu.show_all
            menu
        end

        # Go back / forward

        def update_pages_seen(search_hash)
            if @pages_seen.empty? or @pages_seen[@current_page] != search_hash
                @current_page += 1 unless @pages_seen.length == 0
                @pages_seen[@current_page] = search_hash
                @pages_seen.slice!((@current_page+1..@pages_seen.length-1))
            end
            sensitize_go_buttons
        end
        
        def sensitize_go_buttons          
            @global_actions["GoBack"].sensitive = \
                (@current_page == 0) ? false : true
            @global_actions["GoForward"].sensitive = \
                (@current_page == @pages_seen.length - 1) ? false : true
        end

        # Initialize

        def initialize_ui
            # Tray icon
            if defined? Gtk::TrayIcon and @prefs.show_in_tray
                @main_app.destroy_with_parent = false
                image = Gtk::Image.new(Icon::LOGO_SMALL)
                @tray_event_box = Gtk::EventBox.new.add(image)
                tray = Gtk::TrayIcon.new(Fantasdic::TITLE)
                tray.add(@tray_event_box)
                tray.show_all
            end
            
            # Find pane
            @find_pane.visible = false
            @not_found_label.visible = false

            # Icon
            @main_app.icon = Icon::LOGO_SMALL

            # Entry
            @search_entry.grab_focus

            # Dictionary combobox
            @dictionary_cb.model = Gtk::ListStore.new(String)
            update_dictionary_cb

            # Strategy comboxbox
            @strategy_cb.model = Gtk::ListStore.new(String)
            update_strategy_cb

            # Global actions

            on_search = Proc.new do
                @search_entry.text = ""
                @search_entry.grab_focus
            end

            on_stop = Proc.new do
                @lookup_thread.kill if @lookup_thread and @lookup_thread.alive?
                close_connection(@current_server) if @current_server          
     
                @global_actions["Stop"].visible = false
                @buf.clear
                @iter = @buf.get_iter_at_offset(0)
                self.status_bar_msg = ""
            end

            on_save = Proc.new do
                dialog = Gtk::FileChooserDialog.new(
                            _("Save definition"),
                            @main_app,
                            Gtk::FileChooser::ACTION_SAVE,
                            nil,
                            [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                            [Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_ACCEPT])


                if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
                    File.open(dialog.filename, File::CREAT|File::RDWR) do |f|
                        f.write(@result_text_view.buffer.text)
                    end
                end

                dialog.destroy
            end

            on_quit = Proc.new do
                @lookup_thread.kill if @lookup_thread and @lookup_thread.alive?
                @scan_thread.kill if @scan_thread and @scan_thread.alive?
                save_preferences
                @connections.each do |server, connection|
                    begin
                        connection.disconnect
                    rescue
                    end
                end
                Gtk.main_quit
            end

            on_clear_history = Proc.new do
                @history_listview.model.clear
            end

            on_copy = Proc.new do
               clipboard = Gtk::Clipboard.get(Gdk::Selection::CLIPBOARD)
               sel = @result_text_view.buffer.selected_text
               clipboard.set_text(sel) unless sel.nil?
            end

            on_select_all = Proc.new do
                @result_text_view.select_all(true)
            end

            on_find = Proc.new do
                @not_found_label.visible = false
                @find_pane.visible = true
                @find_entry.text = ""
                @find_entry.grab_focus
                
            end

            on_find_next = Proc.new do
                @find_next_button.clicked
            end

            on_find_prev = Proc.new do
                @find_prev_button.clicked
            end

            on_close_find = Proc.new do
                @find_pane_close_button.clicked
            end

            on_preferences = Proc.new do
                PreferencesDialog.new(@main_app) do
                    update_dictionary_cb
                end
            end

            on_go_back = Proc.new do
                @current_page -= 1
                lookup(@pages_seen[@current_page])
                sensitize_go_buttons
            end

            on_go_forward = Proc.new do
                @current_page += 1
                lookup(@pages_seen[@current_page])
                sensitize_go_buttons
            end

            on_about = Proc.new { AboutDialog.new(@main_app).show }

            # [[name, stock_id, label, accelerator, tooltip, proc], ... ]
            standard_actions = [
                ["FantasdicMenu", nil, "_Fantasdic"],
                ["Search", Gtk::Stock::NEW, _("_Look Up"), nil, nil,
                 on_search],
                ["Save", Gtk::Stock::SAVE, nil, nil, nil, on_save],
                ["Quit", Gtk::Stock::QUIT, nil, nil, nil, on_quit],

                ["EditMenu", nil, _("_Edit")],
                ["Copy", Gtk::Stock::COPY, nil, nil, nil, on_copy],
                ["SelectAll", nil, _("Select _All"), "<ctrl>A", nil,
                 on_select_all],
                ["Find", Gtk::Stock::FIND, nil, nil, nil, on_find],
                ["FindNext", nil, _("Find N_ext"), "<ctrl>G", nil,
                 on_find_next],
                ["FindPrevious", nil, _("Find Pre_vious"), "<ctrl><shift>G",
                 nil, on_find_prev],
                ["ClearHistory", Gtk::Stock::CLEAR, _("Clear history"), nil,
                 nil, on_clear_history],
                ["Preferences", Gtk::Stock::PREFERENCES, nil, nil, nil,
                 on_preferences],

                ["ViewMenu", nil, _("_View")],
                ["GoMenu", nil, _("_Go")],
                ["GoBack", Gtk::Stock::GO_BACK, nil, "<alt>Left", nil,
                 on_go_back],
                ["GoForward", Gtk::Stock::GO_FORWARD, nil, "<alt>Right", nil,
                 on_go_forward],

                ["Stop", Gtk::Stock::STOP, nil, nil, nil, on_stop],

                ["HelpMenu", nil, _("_Help")],
                ["About", Gtk::Stock::ABOUT, _("About"), nil, nil, on_about],

                ["Slash", Gtk::Stock::FIND, nil, "slash", nil, on_find],
                ["Escape", Gtk::Stock::CLOSE, nil, "Escape", nil,
                 on_close_find],
                ["F3", Gtk::Stock::FIND, nil, "F3", nil, on_find_next],
                ["ShiftF3", Gtk::Stock::FIND, nil, "<shift>F3", nil,
                 on_find_prev]                
            ]

            # Toggle actions

            on_toggle_scan_clipboard = Proc.new do
                if @global_actions["ScanClipboard"].active?
                    scan_clipboard
                else
                    @scan_thread.kill
                end
            end
            
            on_toggle_history = Proc.new do
                @sidepane.child1.visible = \
                    @global_actions["ClearHistory"].visible = \
                    @global_actions["History"].active?
            end
            
            on_toggle_statusbar = Proc.new do
                @statusbar.visible = @global_actions["Statusbar"].active?
            end
            
            on_toggle_toolbar = Proc.new do
                @toolbar.visible = @global_actions["Toolbar"].active?
            end

            # [[name, stock_id, label, accel, tooltip, proc, is_active],... ]
            toggle_actions = [
                ["ScanClipboard", nil, _("Scan clipboard"), nil, nil,
                 on_toggle_scan_clipboard, false],
                ["History", nil, _("_History"), "F9", nil, on_toggle_history,
                 true],
                ["Statusbar", nil, _("_Statusbar"), nil, nil,
                 on_toggle_statusbar, true],
                ["Toolbar", nil, _("_Toolbar"), nil, nil, on_toggle_toolbar,
                 true]
            ]

            @global_actions = Gtk::ActionGroup.new("Standard actions")
            @global_actions.add_actions(standard_actions)
            @global_actions.add_toggle_actions(toggle_actions)
            
            @global_actions["GoBack"].sensitive = false
            @global_actions["GoForward"].sensitive = false

            @global_actions["Stop"].visible = false

            # UI Manager
            
            @uimanager = Gtk::UIManager.new
            @uimanager.insert_action_group(@global_actions, 0)
            @main_app.add_accel_group(@uimanager.accel_group)
            
            ["menus.xml", "toolbar.xml", "popups.xml"].each do |ui_file|
                @uimanager.add_ui(File.join(Fantasdic::Config::DATA_DIR,
                                            "ui", ui_file))
            end

            # Add menu and toolbar to the main window
            menubar = @uimanager.get_widget("/MainMenubar")
            @main_app.child.pack_start(menubar,false).reorder_child(menubar,0)
            
            @toolbar = @uimanager.get_widget("/Toolbar")
            @toolbar.border_width = 0
            @main_app.child.pack_start(@toolbar, false)
            @main_app.child.reorder_child(@toolbar, 1)

            @tray_icon_popup = @uimanager.get_widget("/TrayIconPopup")
            @clear_history_popup = @uimanager.get_widget("/ClearHistoryPopup")
        end

        def initialize_signals
            @search_entry.signal_connect("activate") do
                # Perform a search when the user pushes "Enter"
                @search_entry.text = @search_entry.text.strip
                lookup(:dictionary => selected_dictionary,
                       :strategy => selected_strategy,
                       :word => @search_entry.text)
            end

            @history_listview.selection.signal_connect("changed") do
                # Search from history
                if @history_listview.has_row_selected?
                    search = @history_listview.selected_search
                    
                    if @pages_seen.empty? or                    
                        @pages_seen[@current_page] != search
                        lookup(search)
                    end
                end    
            end

            @main_app.signal_connect("delete-event") do
                if defined? Gtk::TrayIcon and @prefs.dont_quit
                    @main_app.hide
                    save_window_preferences
                    true # needed to not destroy the window
                else
                    @global_actions["Quit"].activate
                end
            end

            @tray_event_box.signal_connect("button_press_event") do |w, event|
                if event.kind_of? Gdk::EventButton and event.button == 3
                    # Right click
                    @tray_icon_popup.popup(nil, nil, event.button, event.time)
                elsif event.kind_of? Gdk::EventButton and event.button == 1
                    if @main_app.visible?
                        save_window_preferences
                        @main_app.hide
                    else
                        @main_app.show
                        load_window_preferences
                    end
                end
            end if defined? Gtk::TrayIcon and @prefs.show_in_tray

            IPC::Window.new(IPC::REMOTE) do |p|                    
                @main_app.show
                load_window_preferences              

                @main_app.present

                unless p.empty?
                    lookup(p)
                end
            end if defined? IPC

            @dictionary_cb.signal_connect("changed") do
                update_strategy_cb
            end

            @result_text_view.signal_connect("link_clicked") do
                |w, db, word, event|
                lookup(:dictionary => selected_dictionary,
                       :word => word, :database => db)
            end

            @result_text_view.signal_connect("button_press_event") do |w, ev|
                # Display a popup menu when a row is right-clicked
                if ev.kind_of? Gdk::EventButton and ev.button == 3
                    if @result_text_view.buffer.has_selected_text?
                        sel = @result_text_view.buffer.selected_text
                        dictionary_menu(sel).popup(nil, nil, ev.button,
                                                   ev.time)
                    end
                end
            end

            @find_entry.signal_connect("changed") do |w, ev|
                ret = @result_text_view.find_forward(@find_entry.text, true)    
                @not_found_label.visible = !ret
            end

            @find_prev_button.signal_connect("clicked") do
                ret = @result_text_view.find_backward(@find_entry.text)
                @not_found_label.visible = !ret
            end

            @find_next_button.signal_connect("clicked") do
                ret = @result_text_view.find_forward(@find_entry.text)
                @not_found_label.visible = !ret
            end

            @find_pane_close_button.signal_connect("clicked") do
                @find_pane.visible = false
            end

            @history_listview.signal_connect("button_press_event") do |w, ev|
                if ev.kind_of? Gdk::EventButton and ev.button == 3
                    @clear_history_popup.popup(nil, nil, ev.button,
                                              ev.time)
                end
            end

            @main_app.signal_connect("window-state-event") do |w, e|
                if e.is_a?(Gdk::EventWindowState)
                    @maximized = \
                        e.new_window_state == Gdk::EventWindowState::MAXIMIZED 
                end
            end

        end
    end # class MainApp

end
end
