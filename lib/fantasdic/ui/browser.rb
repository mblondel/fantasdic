# FantasDic
# Copyright (C) 2007 Mathieu Blondel
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
module Browser

def self.could_not_open_browser(url)
    ErrorDialog.new(nil,
                    GetText._("Could not open browser.") + "\n(%s)" % url)
end

def self.could_not_find_documentation
    ErrorDialog.new(nil,
                    GetText._("Could not find documentation."))
end

# Returns first found browser path or nil.
def self.get_browser
    # First try with gconf in order to get the default browser set in
    # System > Preferences > My favourite applications
    begin
        require "gconf2"
        client = GConf::Client.default
        dir = "/desktop/gnome/url-handlers/http/"
        if client[dir + "enabled"]
            return client[dir + "command"]
        end
    rescue LoadError
    end

    # Second, see if user has not set a browser in the prefs file
    prefs = Preferences.instance
    if prefs.www_browser
        return prefs.www_browser
    end

    # Third, try to find if one of those browsers is available
    ["firefox", "iceweasel", "mozilla", "epiphany-browser", "konqueror",
        "w3m"].each do |browser|
        ENV["PATH"].split(":").each do |dir|
            file = File.join(dir, browser)
            if File.executable? file
                return "#{file} %s"
            end
        end
    end

    # Too bad...
    return nil
end

# Opens url in browser and returns true if succeeded
def self.open_url(url)
    if WIN32
        require 'win32ole'
        wsh = WIN32OLE.new('Shell.Application')
        wsh.Open(url)
        return true
    else
        command = get_browser
        if command
            Thread.new { system(command % url) }
            return true
        else
            could_not_open_browser(url)
            return false
        end
    end
end

# Display help using GNOME's help system
def self.open_gnome_help(para)
    begin
        Gnome::Help.display('fantasdic', para)
    rescue => e
        ErrorDialog.new(nil, e.message)
    end
end

# Display help using the browser
def self.open_html_help(para)
    base_path = File.join(Fantasdic::Config::MAIN_DATA_DIR,
                            "doc", "fantasdic", "html")

    found = false
    GLib.language_names.each do |l|
        path = File.join(base_path, l, "index.html")
        if File.exist? path
            found = true
            url = "file://%s" % path
            open_url(url)
            break
        end
    end
    could_not_find_documentation if not found
end

def self.open_help(para=nil)
    if HAVE_GNOME2
        open_gnome_help(para)
    else
        open_html_help(para)
    end
end

end
end
end