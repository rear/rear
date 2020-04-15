
# Dump current keyboard mapping so that it can be set during recovery system startup
# by etc/scripts/system-setup.d/10-console-setup.sh via "loadkeys /etc/dumpkeys.out":
local original_system_dumpkeys_file="/etc/dumpkeys.out"
dumpkeys -f >$ROOTFS_DIR$original_system_dumpkeys_file

# Determine the default directory for keymaps:
# Different Linux distributions use a different default directory for keymaps,
# see https://github.com/rear/rear/pull/1781#issuecomment-384322051
# and https://github.com/rear/rear/pull/1781#issuecomment-384331316
# and https://github.com/rear/rear/pull/1781#issuecomment-384560856
# that read (excerpts):
#   SUSE systems: /usr/share/kbd/keymaps
#   Debian 9.2 (stretch): /usr/share/keymaps
#   Centos 7.3.1611 (Core): /lib/kbd/keymaps
#   Fedora release 26 (Twenty Six): /lib/kbd/keymaps
#   Arch Linux: /usr/share/kbd/keymaps
#   Ubuntu 12.04.5 LTS (Precise): /usr/share/keymaps
#   RHEL 6/7: /lib/kbd/keymaps
# so that we have this summary:
#   /usr/share/kbd/keymaps is used by SUSE and Arch Linux
#   /usr/share/keymaps is used by Debian and Ubuntu
#   /lib/kbd/keymaps is used by Centos and Fedora and Red Hat
# We do not test and distinguish by Linux distribution identifier strings
# because such tests result an endless nightmare to keep them up-to-date.
# We prefer (whenever possible) to generically test "some real thing".
# Accordingly we test known directories and use the first one that exist.
# The last '' is there to keep keymaps_default_directory empty if none of the directories exist
# which is (currently) not strictly requied by the code below but it is cleaner code here:
local keymaps_default_directory=""
for keymaps_default_directory in /usr/share/kbd/keymaps /usr/share/keymaps /lib/kbd/keymaps '' ; do
    test -d "$keymaps_default_directory" && break
done
# Use KEYMAPS_DEFAULT_DIRECTORY if it is explicitly specified by the user:
test $KEYMAPS_DEFAULT_DIRECTORY && keymaps_default_directory="$KEYMAPS_DEFAULT_DIRECTORY"

if test "$keymaps_default_directory" ; then
    # Try to find and include at least the default US keyboard mapping:
    if test -d "$keymaps_default_directory" ; then
        local defkeymap_file="$( find $keymaps_default_directory -name 'defkeymap.*' | head -n1 )"
        if test "$defkeymap_file" ; then
            COPY_AS_IS+=( $defkeymap_file )
        else
            LogPrintError "Cannot include default keyboard mapping (no 'defkeymap.*' found in $keymaps_default_directory)"
        fi
    else
        LogPrintError "Cannot include default keyboard mapping (no keymaps default directory '$keymaps_default_directory')"
    fi
else
    LogPrintError "Cannot include default keyboard mapping (no KEYMAPS_DEFAULT_DIRECTORY specified)"
fi

# Additionally include other keyboard mappings to also support users with a non-US keyboard
# who can then manually switch to their keyboard mapping (e.g. via a command like "loadkeys de-latin1")
# or who had specdified the KEYMAP that should be used in the recovery system.
# It is not sufficient to include only map.gz or only i386 files because all the include files are also needed.
# Including the whole keymaps default directory increases the recovery system size by about 3 MB
# and including only the 'legacy' subdirectory increases the recovery system size by about 1 MB
# (an usual recovery system size is about 500 MB uncompressed where about 250 MB are firmware files)
# but without the right keyboard mapping it could become an awful annoyance to work in the recovery system
# so that by default and as fallback the whole keymaps default directory is included to be on the safe side,
# cf. https://github.com/rear/rear/pull/1781#issuecomment-384232695
local keymaps_directories=$keymaps_default_directory
# Use KEYMAPS_DIRECTORIES if it is explicitly specified by the user:
contains_visible_char "$KEYMAPS_DIRECTORIES" && keymaps_directories="$KEYMAPS_DIRECTORIES"
if test "$keymaps_directories" ; then
    COPY_AS_IS+=( $keymaps_directories )
else
    LogPrintError "Cannot include keyboard mappings (neither KEYMAPS_DEFAULT_DIRECTORY nor KEYMAPS_DIRECTORIES specified)"
fi

