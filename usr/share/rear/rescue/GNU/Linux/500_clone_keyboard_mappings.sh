
# Dump current keyboard mapping to etc/dumpkeys.out so that it can be set during recovery system startup
# by etc/scripts/system-setup.d/10-console-setup.sh via "loadkeys /etc/dumpkeys.out"
# but depending on the keyboard mapping the "loadkeys /etc/dumpkeys.out" command
# may not work in the recovery system so that some other keyboard mapping files
# are also included so that the user can manually set his keyboard mapping:
dumpkeys -f1 >$ROOTFS_DIR/etc/dumpkeys.out

# At least include the default US keyboard mapping:
defkeymap_file="$( find /usr/share/kbd/keymaps -name 'defkeymap.*' | head -n1 )"
if test $defkeymap_file ; then
    COPY_AS_IS=( "${COPY_AS_IS[@]}" $defkeymap_file )
else
    # If no defkeymap file was found in /usr/share/kbd/keymaps try some RHEL, SLES and Ubuntu qwerty flavours.
    # The funny ? makes 'shopt -s nullglob' remove this file from the list if it does not exist:
    COPY_AS_IS=( "${COPY_AS_IS[@]}" /lib/k?d/keymaps/i386/qwerty/defkeymap.map.gz /usr/share/k?d/keymaps/i386/qwerty/defkeymap.map.gz /usr/share/ke?maps/i386/qwerty/defkeymap.map.gz )
fi

# Additionally include the legacy keyboard mappings to also support users with a non-US keyboard
# who can then manually switch to their keyboard mapping (e.g. via a command like "loadkeys de-latin1").
# It is not sufficient to include only map.gz or only i386 files because all the include files are also needed.
# This increases the recovery system size by about 1 MB (an usual recovery system size is about 500 MB uncompressed)
# but without the right keyboard mapping it could become an awful annoyance to work in the recovery system:
test -d /usr/share/kbd/keymaps/legacy && COPY_AS_IS=( "${COPY_AS_IS[@]}" /usr/share/kbd/keymaps/legacy )

