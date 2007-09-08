/*
# Fantasdic
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
*/

/* Fantasdic launcher for Windows */

#include <windows.h> 
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define FANTASDIC_COMMAND "lib/ruby/bin/rubyw lib/fantasdic/bin/fantasdic"
#define FANTASDIC_DBG_COMMAND "lib/ruby/bin/ruby lib/fantasdic/bin/fantasdic"

static void
get_dirname (char *path, char *dirname)
{
    int i = 0;
    int last = 0;
    int len = strlen (path);
    while (i < len) {
        if (path[i] == '/' || path[i] == '\\' )
            last = i;
        i++;
    }
    strncpy (dirname, path, last + 1);
    dirname[last + 1] = '\0';
} 

int 
main(int argc, char **argv)
{
    STARTUPINFO si = { sizeof (STARTUPINFO) };
    PROCESS_INFORMATION pi;
    char full_app_path[MAX_PATH + 1];
    char dirname[MAX_PATH + 1];
    char *cmd;

    GetModuleFileName(NULL, full_app_path, sizeof (full_app_path));
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    
    get_dirname (full_app_path, dirname);
    
    if (argc > 1 && strcmp (argv[1], "-d") == 0)
        cmd = FANTASDIC_DBG_COMMAND;
    else
        cmd = FANTASDIC_COMMAND;

    if( !CreateProcess( NULL,   /* No module name (use command line) */
        cmd,                    /* Command line */
        NULL,                   /* Process handle not inheritable */
        NULL,                   /* Thread handle not inheritable */
        FALSE,                  /* Set handle inheritance to FALSE */
        0,                      /* No creation flags */
        NULL,                   /* Use parent's environment block */
        dirname,                /* Set current directory for the process */
        &si,                    /* Pointer to STARTUPINFO structure */
        &pi ))                  /* Pointer to PROCESS_INFORMATION structure */
    
    {
        printf( "CreateProcess failed (%d)\n", GetLastError() );
        return;
    }

    return 0;
}
