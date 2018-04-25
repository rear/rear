
# Dump current keyboard mapping so that it can be set during recovery system startup
# by etc/scripts/system-setup.d/10-console-setup.sh via "loadkeys /etc/dumpkeys.out":
local original_system_dumpkeys_file="/etc/dumpkeys.out"
dumpkeys -f >$ROOTFS_DIR$original_system_dumpkeys_file

# At least on SUSE systems /usr/share/kbd/keymaps is the default directory for keymaps:
local keymaps_default_directory="/usr/share/kbd/keymaps"

# Use KEYMAPS_DEFAULT_DIRECTORY if it is explicitly specified by the user:
test $KEYMAPS_DEFAULT_DIRECTORY && keymaps_default_directory="$KEYMAPS_DEFAULT_DIRECTORY"

# Report when there is no keymaps default directory because other keyboard mappings (at least 'defkeymap') should get included
# but that is not a severe error because the current keyboard mapping is dumped and gets used by default and as fallback:
test -d $keymaps_default_directory || LogPrintError "Cannot include keyboard mappings (no keymaps default directory $keymaps_default_directory)"

# Try to include at least the default US keyboard mapping:
local defkeymap_file="$( find $keymaps_default_directory -name 'defkeymap.*' | head -n1 )"
if test $defkeymap_file ; then
    COPY_AS_IS=( "${COPY_AS_IS[@]}" $defkeymap_file )
else
    # If no defkeymap file was found in $keymaps_default_directory try some RHEL, SLES and Ubuntu qwerty flavours.
    # The funny ? makes 'shopt -s nullglob' remove such a file from the list if it does not exist:
    COPY_AS_IS=( "${COPY_AS_IS[@]}" /lib/k?d/keymaps/i386/qwerty/defkeymap.map.gz /usr/share/k?d/keymaps/i386/qwerty/defkeymap.map.gz /usr/share/ke?maps/i386/qwerty/defkeymap.map.gz )
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
COPY_AS_IS=( "${COPY_AS_IS[@]}" $keymaps_directories )

