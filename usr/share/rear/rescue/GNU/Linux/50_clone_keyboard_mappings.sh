# Dump current keyboard mappings to default
dumpkeys -f1 >$ROOTFS_DIR/etc/dumpkeys.out

# Also include the US keyboard mappings
COPY_AS_IS=( "${COPY_AS_IS[@]}" /lib/kbd/keymaps/i386/qwerty/defkeymap.map.gz )
