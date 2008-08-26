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

require "thread"

module Fantasdic
module UI

    module Icon
        icons_dir = File.join(Config::DATA_DIR, "icons")
        LOGO_16X16 = Gdk::Pixbuf.new(File.join(icons_dir,
                                               "fantasdic_16x16.png"))
        LOGO_22X22 = Gdk::Pixbuf.new(File.join(icons_dir,
                                               "fantasdic_22x22.png"))
        LOGO_48X48 = Gdk::Pixbuf.new(File.join(icons_dir,
                                               "fantasdic_48x48.png"))
        PRINT_SETUP = "stock_print-setup"
    end

    class MainApp < GladeBase
        include GetText
        GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

        module Action
            DEFINE = 0
            MATCH = 1
            DEFINE_MATCH = 2
        end

        def initialize(start_p={})
            super("main_app.glade")
            @prefs = Preferences.instance            

            @start_p = start_p
            @looking_up_mutex = Mutex.new

            @main_app.hide
            initialize_ui
            initialize_signals
            clear_pages_seen
            load_preferences
            @main_app.show unless @prefs.dont_show_at_startup

            lookup(@start_p) unless @start_p.empty?
        end

        def lookup(search)
            search[:word].strip!
            return false if search[:word].empty?

            Thread.new do
                debug("Trying to acquire lock...")
                kill_lookup_thread
                @looking_up_mutex.lock
                debug("Got lock! Start search!")
                @lookup_thread = Thread.new { lookup_real(search) }
                @lookup_thread.join
                @looking_up_mutex.unlock
            end
        end

        private

        def debug(msg)
            $stderr.puts "[DEBUG] %s %s" % [Time.now, msg] if $DEBUG
        end

        def lookup_real(p)
            Gtk.thread_protect { @buf.clear }

            if @dictionary_cb.model.nb_rows == 0
                Gtk.thread_protect do
                    msg = _("No dictionary configured")
                    self.status_bar_msg = msg
                    @buf.insert_header(msg + "\n")
                end
                return
            end

            if p[:dictionary]
                Gtk.thread_protect do
                    self.selected_dictionary = p[:dictionary]
                end
            else
                p[:dictionary] = selected_dictionary
            end

            unless p[:action] == Action::DEFINE_MATCH
                Gtk.thread_protect do
                    @search_entry.text = p[:word]
                    self.selected_strategy = p[:strategy]
                end
            end

            hash = @prefs.dictionaries_infos[p[:dictionary]]

            Gtk.thread_protect { @global_actions["Stop"].visible = true }

            # Get connection
            begin
                # This error is raised when a word is searched
                # through the history while the associated dictionary
                # does not exist anymore in the settings
                if !hash
                    raise Source::SourceError,
                    _("Dictionary \"%s\" does not exist anymore") % \
                    p[:dictionary]
                end

                source_class = Source::Base.get_source(hash[:source])

                # This error is raised when a plugin source doesn't exist
                # anymore
                if !source_class
                    raise Source::SourceError,
                    _("Dictionary source \"%s\" does not exist anymore") % \
                    hash[:source]
                end

                source = source_class.new(hash)

                self.status_bar_msg = source.connecting_to_source_str

                source.open
            rescue Source::SourceError => e
                source_error(e)
                return
            end

            Gtk.thread_protect { set_font_name(hash[:results_font_name]) }

            if p[:strategy] and
                p[:strategy] != source_class.default_strategy
                # Search with match strategy.

                Gtk.thread_protect do
                    @matches_listview.sensitive = false
                    @matches_listview.model.clear
                end

                begin
                    matches = match(source, p)
                    Gtk.thread_protect do
                        insert_matches(matches)

                        if matches.length > 0
                            @matches_listview.select_first
                            @global_actions["MatchesSidepane"].active = true
                        else
                            @global_actions["MatchesSidepane"].active = \
                                false
                        end

                        @search_cb_entry.update(p)
                    end
                rescue Source::SourceError => e
                    source_error(e)
                    return
                end

                Gtk.thread_protect do
                    disable_print
                    clear_pages_seen
                    @matches_listview.sensitive = true
                end
            else
                # Define
                begin
                    definitions = define(source, p)
                    Gtk.thread_protect do
                        insert_definitions(definitions)

                        unless p[:action] == Action::DEFINE_MATCH
                            @search_cb_entry.update(p)
                            @global_actions["MatchesSidepane"].active = \
                                false
                        else
                            @global_actions["MatchesSidepane"].active = true
                            @matches_listview.select_match(p[:word])
                        end


                        @result_text_view.grab_focus

                        if definitions.empty?
                            disable_print
                            disable_save
                        else
                            enable_print
                            enable_save
                        end

                        update_pages_seen(p)
                    end
                rescue Source::SourceError => e
                    source_error(e)
                end
            end

            source.close

            Gtk.thread_protect { @global_actions["Stop"].visible = false }
        end

        def kill_lookup_thread
            if @lookup_thread and @lookup_thread.alive?
                debug("Kill current thread!")
                @lookup_thread.kill

                while @lookup_thread and @lookup_thread.alive?
                    debug("Waiting for the thread to stop...")
                    sleep 0.2
                end

                DICTClient.close_active_connection
            end

            Gtk.thread_protect do
                @global_actions["Stop"].visible = false
                @buf.clear
                self.status_bar_msg = ""
            end
            Gtk.thread_flush
        end

        def source_error(e)
            Gtk.thread_protect do
                @buf.insert_header(_("Source error") + "\n")
                @buf.insert_text(e.to_s)
                self.status_bar_msg = e.to_s
                @global_actions["Stop"].visible = false
            end
        end

        def define(source, p)
            hash = @prefs.dictionaries_infos[p[:dictionary]]

            Gtk.thread_protect do
                self.status_bar_msg = source.transferring_data_str
            end

            if !p[:database].nil?
                source.cached_multiple_define([p[:database]], p[:word])
            elsif hash[:all_dbs] == true
                source.cached_multiple_define([Source::Base::ALL_DATABASES],
                                           p[:word])
            else
                source.cached_multiple_define(hash[:sel_dbs], p[:word])
            end
        end

        def insert_definitions(definitions)
            @buf.clear
            
            @buf.insert_definitions(definitions)

            # Status bar
            if definitions.empty?
                msg = _("No definition found.")
                self.status_bar_msg = msg
                @buf.insert_header(msg)
            else 
                msg = ngettext("One definition found.",
                               "Definitions found: %d.",
                               definitions.length)
                msg = msg % definitions.length if definitions.length > 1
                self.status_bar_msg = msg
            end
        end

        def match(source, p)  
            hash = @prefs.dictionaries_infos[p[:dictionary]]

            Gtk.thread_protect do
                self.status_bar_msg = source.transferring_data_str
            end

            if hash[:all_dbs] == true
                source.cached_multiple_match([Source::Base::ALL_DATABASES],
                                           p[:strategy],
                                           p[:word])
            else
                source.cached_multiple_match(hash[:sel_dbs],
                                           p[:strategy],
                                           p[:word])
            end
        end
      
        def insert_matches(matches)
            @buf.clear            

            if matches.length > 0
                @matches_listview.append_matches(matches)

                nb_match = @matches_listview.model.n_rows

                self.status_bar_msg = ""

                msg = \
                    ngettext("1 match", "%d matches", nb_match)
                msg = msg % nb_match if nb_match > 1
                @matches_label.text = msg
            else
                msg = _("No match found.")
                @matches_label.text = _("Matches")
                @buf.insert_header(msg)
                self.status_bar_msg = msg
            end            
        end

        def status_bar_msg=(message)
            @statusbar.push(0, message)
        end

        def set_font_name(font_name)
            @result_text_view.buffer.font_name = font_name
        end

        def scan_clipboard            
            last_selection = nil
            clipboard = Gtk::Clipboard.get(Gdk::Selection::CLIPBOARD)
            clipboard.request_text do |cb, text|
                last_selection = text
            end

            GLib::Timeout.add(800) do
                clipboard.request_text do |cb, text|
                    if text != last_selection
                        unless text.nil? or text.empty? or \
                               text == @search_entry.text or \
                               text =~ /^(http|ftp|file)/

                            last_selection = text
                            lookup(:word => text)
                            @main_app.show unless @main_app.visible?
                            @main_app.present
                        end
                    end
                end
                @scan_clipboard
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
            @matches_sidepane.position = @prefs.sidepane_position
            @global_actions["KeepAbove"].active = @prefs.keep_above
        end

        def load_last_searches
            @prefs.last_searches.each do |search|
                @search_cb_entry.append_search(search)
            end
            
            unless @prefs.last_searches.nil? or \
                   @prefs.last_searches.length == 0 or \
                   @prefs.lookup_at_start.nil? or \
                   @prefs.lookup_at_start == false or !@start_p.empty?

                lookup(@prefs.last_searches.first) 
            end
        end

        def load_print_preferences
            # Page Setup
            if @prefs.paper_size and @prefs.page_orientation
                @page_setup = Gtk::PageSetup.new
                @page_setup.orientation = \
                    Gtk::PrintSettings.const_get(@prefs.page_orientation)
                paper_size = Gtk::PaperSize.new(@prefs.paper_size)
                @page_setup.paper_size_and_default_margins = paper_size
            end

            # Print Settings
            if @prefs.print_settings
                @print_settings = Gtk::PrintSettings.new
                @prefs.print_settings.each do |key, value|
                    @print_settings.set(key, value)
                end
            end
        end

        def load_dictionary_preferences
            if @prefs.selected_dictionary
                self.selected_dictionary = @prefs.selected_dictionary
            end

            dic = @prefs.dictionaries_infos[selected_dictionary]
            if dic and dic[:sel_strat]
                self.selected_strategy = dic[:sel_strat]
            end
        end

        def load_proxy_preferences
            # SOCKS
            if @prefs.enable_proxy
                if @prefs.proxy_host and @prefs.proxy_port
                    ENV['SOCKS_SERVER'] = "%s:%s" % [@prefs.proxy_host,
                                                    @prefs.proxy_port]
                end
                if @prefs.proxy_user and @prefs.proxy_password
                    ENV['SOCKS_USER'] = @prefs.proxy_user
                    ENV['SOCKS_PASSWORD'] = @prefs.proxy_password
                end
            else
                ['SOCKS_SERVER', 'SOCKS_USER', 'SOCKS_PASSWORD'].each do |k|
                    ENV.delete(k)
                end
            end
            # HTTP
            if @prefs.enable_http_proxy
                ENV['http_proxy'] = "http://%s:%s" % [@prefs.http_proxy_host,
                                                      @prefs.http_proxy_port]
            else
                ENV.delete('http_proxy')
            end
        end

        def load_misc_preferences
            @global_actions["ScanClipboard"].active = @prefs.scan_clipboard
        end

        def load_preferences            
            load_window_preferences
            load_print_preferences if HAVE_PRINT
            load_dictionary_preferences
            load_proxy_preferences
            load_misc_preferences
            load_last_searches
        end

        def save_window_preferences
            @prefs.view_statusbar = @global_actions["Statusbar"].active?
            @prefs.view_toolbar = @global_actions["Toolbar"].active?
            @prefs.sidepane_position = @matches_sidepane.position
            @prefs.window_maximized = @maximized
            @prefs.window_size = @main_app.size
            @prefs.window_position = @main_app.position
            @prefs.keep_above = @global_actions["KeepAbove"].active?
        end

        def save_last_searches
            @prefs.last_searches = []
            @search_cb_entry.model.each do |model, path, iter|
                @prefs.last_searches <<
                    iter[ComboBoxEntry::Column::SEARCH_HASH]
            end
            @prefs.last_search = @pages_seen[@current_page]
        end

        def save_print_preferences
            if @page_setup
                @prefs.page_orientation = \
                    @page_setup.orientation.name.gsub(/^GTK_PAGE_/, "")
                @prefs.paper_size = @page_setup.paper_size.name
            end

            @prefs.print_settings = @print_settings.to_a if @print_settings
        end

        def save_dictionary_preferences
            @prefs.selected_dictionary = selected_dictionary
        end

        def save_misc_preferences
            @prefs.scan_clipboard = @global_actions["ScanClipboard"].active?
        end

        def save_preferences
            save_window_preferences
            save_last_searches
            save_dictionary_preferences
            save_print_preferences if HAVE_PRINT
            save_misc_preferences
            @prefs.save!
        end

        def save_selected_dictionary_font_name
            sel_dic = @prefs.dictionaries_infos[selected_dictionary]
            sel_dic[:results_font_name] = @result_text_view.buffer.font_name
        end

        # Search entry

        def update_search_entry_font
            hash = @prefs.dictionaries_infos[selected_dictionary]

            if hash and hash[:results_font_name]
                # Change font but don't change size
                font_name = hash[:results_font_name]
                font_desc = Pango::FontDescription.new(font_name)
                font_desc.size = @search_entry_default_font_desc.size
                @search_entry.modify_font(font_desc)
            end
        end

        # Strategy menu

        def update_strategy_cb
            @strategy_cb.model.clear
            hash = @prefs.dictionaries_infos[selected_dictionary]

            if hash
                @strategy_cb.sensitive = true                
                dflt_strat = default_strategy_of_selected_dictionary
                strats = [dflt_strat]
                strats += hash[:avail_strats] unless hash[:avail_strats].nil?
                strats.uniq!

                strats.each do |strat|
                    row = @strategy_cb.model.append
                    row[0] = strat    
                end

                if hash[:sel_strat]
                    self.selected_strategy = hash[:sel_strat]
                else
                    self.selected_strategy = dflt_strat
                end
            else
                @strategy_cb.sensitive = false
            end
        end

        def selected_strategy
            n = @strategy_cb.active
            @strategy_cb.model.get_iter(n.to_s)[0] if n >= 0                
        end

        def selected_strategy=(strat)
            strat = default_strategy_of_selected_dictionary if strat.nil?
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
                sensitive = false
                @prefs.dictionaries.each do |dic|
                    if @prefs.dictionaries_infos[dic][:selected] == 1
                        row = @dictionary_cb.model.append
                        row[0] = dic
                        sensitive = true
                    end
                end
                @dictionary_cb.active = 0
                @dictionary_cb.sensitive = sensitive
            else
                @dictionary_cb.sensitive = false
            end
        end

        def default_strategy_of_selected_dictionary
            hash = @prefs.dictionaries_infos[selected_dictionary]
            source_class = Source::Base.get_source(hash[:source])
            source_class.default_strategy
        end

        def selected_dictionary
            selected = @dictionary_cb.active
            if selected >= 0
                @dictionary_cb.model.get_iter(selected.to_s)[0]
            else
                nil
            end
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
            dicname
        end

        def dictionary_menu_append_search_item(menu, name, word)
            item = Gtk::MenuItem.new(_("Search %s") % name)
            item.signal_connect("activate") do
                lookup(:word => word, :dictionary => name)
            end
            menu.append(item)
        end

        def dictionary_menu(word)
            menu = Gtk::Menu.new

            # Search menu items
            dictionary_menu_append_search_item(menu, selected_dictionary, word)
           
            menu.append(Gtk::SeparatorMenuItem.new)
            @dictionary_cb.model.each do |model, path, iter|
                name = iter[0]
                if name != selected_dictionary              
                    dictionary_menu_append_search_item(menu, name, word)
                end
            end
            menu.append(Gtk::SeparatorMenuItem.new)

            # Zoom            
            if word.strip.utf8_length == 1
                item = Gtk::ImageMenuItem.new(_("Zoom over character"))
                item.signal_connect("activate") do |mitem|
                    CharacterZoomWindow.new(@main_app, word.strip)
                end
                menu.append(item)
                menu.append(Gtk::SeparatorMenuItem.new)
            end

            # Copy and select all
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

        def clear_pages_seen
            @pages_seen = []
            @current_page = 0
            sensitize_go_buttons
        end

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
                (@pages_seen.length == 0 or
                 @current_page == @pages_seen.length - 1) ? false : true
        end

        # Save
        def disable_save
            @global_actions["Save"].sensitive = false
        end

        def enable_save
            @global_actions["Save"].sensitive = true
        end

        # Print
        def disable_print_if_unsupported
            if HAVE_PRINT
                disable_print
            else
                ["PrintSetup", "PrintPreview", "Print"].each do |a|
                    @global_actions[a].visible = false
                end
            end
        end

        def disable_print
            if HAVE_PRINT
                ["PrintPreview", "Print"].each do |a|
                    @global_actions[a].sensitive = false
                end
            end
        end

        def enable_print
            if HAVE_PRINT
                ["PrintPreview", "Print"].each do |a|
                    @global_actions[a].sensitive = true
                end
            end
        end   

        # Initialize

        def initialize_ui
            Gtk.init_thread_protect

            # Tray icon
            if HAVE_STATUS_ICON
                @main_app.destroy_with_parent = false                
                @statusicon = Gtk::StatusIcon.new
                @statusicon.pixbuf = Icon::LOGO_22X22
                @statusicon.visible = @prefs.show_in_tray            
            end
            
            # Find pane
            @find_pane.visible = false
            @not_found_label.visible = false

            # Icon
            @main_app.icon = Icon::LOGO_16X16

            # Entry
            @search_entry = @search_cb_entry.child
            @search_entry.grab_focus
            @search_entry_default_font_desc = @search_entry.style.font_desc

            # Dictionary combobox
            @dictionary_cb.model = Gtk::ListStore.new(String)
            update_dictionary_cb
            update_search_entry_font

            # Strategy comboxbox
            @strategy_cb.model = Gtk::ListStore.new(String)
            update_strategy_cb

            # Result text view (instance created by glade)
            @buf = @result_text_view.buffer
            @result_text_view.buffer.scrolled_window = @result_sw

            # Sidepane
            @matches_sidepane.child1.visible = false

            # Global actions

            # File

            on_search = Proc.new do
                @search_entry.text = ""
                @search_entry.grab_focus
                @statusicon.activate if !@main_app.visible? and @statusicon
            end

            on_stop = Proc.new do
                kill_lookup_thread
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

            on_print_setup = Proc.new do
                @page_setup = Print::run_page_setup_dialog(@main_app,
                                                           @page_setup)
            end

            on_print = Proc.new do
                @print = Print.new(@main_app,
                                   @search_entry.text,
                                   selected_dictionary,
                                   @result_text_view.buffer.definitions)

                @print.default_page_setup = @page_setup if @page_setup
                @print.print_settings = @print_settings if @print_settings

                @print.run_print_dialog

                @print_settings = @print.print_settings
            end

            on_print_preview = Proc.new do
                @print = Print.new(@main_app,
                                   @search_entry.text,
                                   selected_dictionary,
                                   @result_text_view.buffer.definitions)

                @print.default_page_setup = @page_setup if @page_setup

                @print.run_preview
            end

            on_quit = Proc.new do
                kill_lookup_thread
                Gtk.thread_flush
                save_preferences
                Gtk.main_quit
            end

            # Edit

            on_copy = Proc.new do
               clipboard = Gtk::Clipboard.get(Gdk::Selection::CLIPBOARD)
               sel = @result_text_view.buffer.selected_text
               clipboard.set_text(sel) unless sel.nil?
            end

            on_select_all = Proc.new do
                @result_text_view.select_all(true)
            end

            on_clear_history = Proc.new do
                @search_cb_entry.model.clear
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
                if @statusicon and @prefs.show_in_tray and \
                   @prefs.dont_quit and !@find_pane.visible? \

                   @on_delete_event_proc.call
                end
                @find_pane_close_button.clicked
            end

            on_preferences = Proc.new do
                save_dictionary_preferences
                PreferencesDialog.new(@main_app,
                                      @statusicon) do
                    # This block is called when the dialog is closed
                    #DICTClient.close_all_connections
                    update_dictionary_cb
                    load_dictionary_preferences
                    load_proxy_preferences
                    update_strategy_cb
                    @prefs.save!
                end
            end

            # View
            on_zoom_plus = Proc.new do
                @result_text_view.buffer.increase_size
                save_selected_dictionary_font_name
            end

            on_zoom_minus = Proc.new do
                @result_text_view.buffer.decrease_size
                save_selected_dictionary_font_name
            end

            on_zoom_normal = Proc.new do
                @result_text_view.buffer.set_default_size
                save_selected_dictionary_font_name
            end

            # Go

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

            # Help

            on_help = Proc.new do
                Browser::open_help
            end

            on_submit_bug_report = Proc.new do
                url = Fantasdic::BUGZILLA_REPORT_BUG
                Browser::open_url(url)
            end

            on_about = Proc.new { AboutDialog.new(@main_app).show }

            # [[name, stock_id, label, accelerator, tooltip, proc], ... ]
            standard_actions = [
                # File
                ["FantasdicMenu", nil, "_Fantasdic"],
                ["Search", Gtk::Stock::NEW, nil, nil, nil,
                 on_search],
                ["Save", Gtk::Stock::SAVE, nil, nil, nil, on_save],
                ["PrintSetup", Icon::PRINT_SETUP, _("Print Set_up"), nil, nil,
                 on_print_setup],
                ["Print", Gtk::Stock::PRINT, nil, "<ctrl>P", nil, on_print],
                ["PrintPreview", Gtk::Stock::PRINT_PREVIEW, nil,
                 "<ctrl><shift>P", nil, on_print_preview],
                ["Quit", Gtk::Stock::QUIT, nil, nil, nil, on_quit],

                #Edit
                ["EditMenu", nil, _("_Edit")],
                ["Copy", Gtk::Stock::COPY, nil, nil, nil, on_copy],
                ["SelectAll", nil, _("Select _All"), "<ctrl>A", nil,
                 on_select_all],
                ["ClearHistory", Gtk::Stock::CLEAR, _("Clear History"), nil,
                 nil, on_clear_history],
                ["Find", Gtk::Stock::FIND, nil, nil, nil, on_find],
                ["FindNext", nil, _("Find N_ext"), "<ctrl>G", nil,
                 on_find_next],
                ["FindPrevious", nil, _("Find Pre_vious"), "<ctrl><shift>G",
                 nil, on_find_prev],
                ["Preferences", Gtk::Stock::PREFERENCES, nil, nil, nil,
                 on_preferences],

                # View
                ["ViewMenu", nil, _("_View")],
                ["TextSizeMenu", nil, _("_Text size")],
                ["ZoomPlus", Gtk::Stock::ZOOM_IN, nil, "<ctrl>plus", nil,
                 on_zoom_plus],
                ["ZoomMinus", Gtk::Stock::ZOOM_OUT, nil, "<ctrl>minus", nil,
                 on_zoom_minus],
                ["ZoomNormal", nil, _("Zoom normal"), "<ctrl>0", nil,
                 on_zoom_normal],

                # Go
                ["GoMenu", nil, _("_Go")],
                ["GoBack", Gtk::Stock::GO_BACK, nil, "<alt>Left", nil,
                 on_go_back],
                ["GoForward", Gtk::Stock::GO_FORWARD, nil, "<alt>Right", nil,
                 on_go_forward],

                ["Stop", Gtk::Stock::STOP, nil, nil, nil, on_stop],

                # Help
                ["HelpMenu", nil, _("_Help")],
                ["Help", Gtk::Stock::HELP, _("_Contents"), "F1", nil, on_help],
                ["SubmitBugReport", Gtk::Stock::EDIT, _("Submit _Bug Report"),
                 nil, nil, on_submit_bug_report],
                ["About", Gtk::Stock::ABOUT, _("About"), nil, nil, on_about],

                # Accelerators
                ["Slash", Gtk::Stock::FIND, nil, "slash", nil, on_find],
                ["Escape", Gtk::Stock::CLOSE, nil, "Escape", nil,
                 on_close_find],
                ["F3", Gtk::Stock::FIND, nil, "F3", nil, on_find_next],
                ["ShiftF3", Gtk::Stock::FIND, nil, "<shift>F3", nil,
                 on_find_prev],
                ["CtrlEqual", Gtk::Stock::FIND, nil, "<ctrl>equal", nil,
                 on_zoom_plus]
               
            ]

            # Toggle actions

            on_toggle_scan_clipboard = Proc.new do                
                @scan_clipboard = @global_actions["ScanClipboard"].active?
                scan_clipboard if @scan_clipboard
            end

            on_toggle_matches_sidepane = Proc.new do
                @matches_sidepane.child1.visible = \
                    @global_actions["MatchesSidepane"].active?
            end
            
            on_toggle_statusbar = Proc.new do
                @statusbar.visible = @global_actions["Statusbar"].active?
            end
            
            on_toggle_toolbar = Proc.new do
                @toolbar.visible = @global_actions["Toolbar"].active?
            end

            on_toggle_keep_above = Proc.new do
                @main_app.keep_above = @global_actions["KeepAbove"].active?
            end

            # [[name, stock_id, label, accel, tooltip, proc, is_active],... ]
            toggle_actions = [
                ["ScanClipboard", nil, _("Scan clipboard"), "<ctrl><shift>S",
                 nil, on_toggle_scan_clipboard, false],
                ["MatchesSidepane", nil, _("_Matches"), "F9", nil,
                 on_toggle_matches_sidepane, false],
                ["Statusbar", nil, _("_Statusbar"), nil, nil,
                 on_toggle_statusbar, true],
                ["Toolbar", nil, _("_Toolbar"), nil, nil, on_toggle_toolbar,
                 true],
                ["KeepAbove", nil, _("_Keep above"),
                 "<ctrl><shift>K", nil, on_toggle_keep_above, false]
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

            @statusicon_popup = @uimanager.get_widget("/StatusIconPopup")

            disable_print_if_unsupported
            disable_save
        end

        def initialize_signals
            @search_entry.signal_connect("activate") do
                # Perform a search when the user pushes "Enter"
                @search_entry.text = @search_entry.text.strip
                lookup(:dictionary => selected_dictionary,
                       :strategy => selected_strategy,
                       :word => @search_entry.text)
            end

            @matches_listview.selection.signal_connect("changed") do
                if @matches_listview.has_row_selected?
                    match = @matches_listview.selected_match
                    if @pages_seen.empty? or
                       @pages_seen[@current_page][:word] != match

                        lookup(:dictionary => selected_dictionary,
                                :word => match,
                                :action => Action::DEFINE_MATCH)
                    end
                end
            end

            @on_delete_event_proc = Proc.new do
                if @statusicon and @prefs.dont_quit                    
                    save_window_preferences
                    @main_app.hide_on_delete
                else
                    @global_actions["Quit"].activate
                end
            end

            @main_app.signal_connect("delete-event") do
                @on_delete_event_proc.call
            end

            @statusicon.signal_connect("popup-menu") do
            |w, button, activate_time|
                @statusicon_popup.popup(nil, nil, button, activate_time)
            end if @statusicon

            @statusicon.signal_connect("activate") do |w, event|
                if @main_app.visible?
                    save_window_preferences
                    @main_app.hide
                else
                    @main_app.show
                    load_window_preferences
                    @result_text_view.grab_focus
                end
            end if @statusicon

            IPC::Instance.new(IPC::Instance::REMOTE) do |p|
                @main_app.show
                load_window_preferences              

                @main_app.present

                unless p.empty?
                    lookup(p)
                end
            end

            @result_text_view.signal_connect("link_clicked") do
                |widget, word, event|
                lookup(:dictionary => selected_dictionary,
                       :word => word,
                       :strategy => default_strategy_of_selected_dictionary)
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

            @main_app.signal_connect("window-state-event") do |w, e|
                if e.is_a?(Gdk::EventWindowState)
                    @maximized = \
                        e.new_window_state == Gdk::EventWindowState::MAXIMIZED 
                end
            end

            @sidepane_close_button.signal_connect("clicked") do
                @global_actions["MatchesSidepane"].active = false
            end

            @dictionary_cb.signal_connect("changed") do
                # Update the cb with the available strats
                update_strategy_cb
                update_search_entry_font
            end

            @strategy_cb.signal_connect("changed") do
                # Save strategy
                dic = @prefs.dictionaries_infos[selected_dictionary]
                if dic
                    dic[:sel_strat] = selected_strategy
                end
            end

            @search_cb_entry.signal_connect("changed") do
                iter = @search_cb_entry.active_iter
                if iter
                    search = iter[ComboBoxEntry::Column::SEARCH_HASH]
                    lookup(search)
                end
            end

        end
    end # class MainApp

end
end
