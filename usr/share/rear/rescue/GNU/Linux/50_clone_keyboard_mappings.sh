# Dump current keyboard mappings to default
dumpkeys -f1 >$ROOTFS_DIR/etc/dumpkeys.out

# Also include the US keyboard mappings
# Adding RHEL, SLES and Ubuntu qwerty flavours
COPY_AS_IS=( "${COPY_AS_IS[@]}" /lib/k?d/keymaps/i386/qwerty/defkeymap.map.gz /usr/share/k?d/keymaps/i386/qwerty/defkeymap.map.gz /usr/share/ke?maps/i386/qwerty/defkeymap.map.gz )
