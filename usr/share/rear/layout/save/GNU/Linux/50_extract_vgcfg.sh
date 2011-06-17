# Use vgcfgbackup to copy the current LVM setup exactly

if ! has_binary lvm; then
    return
fi

mkdir -p $v $VAR_DIR/layout/lvm >&2
lvm 8>&- 7>&- vgcfgbackup -f $VAR_DIR/layout/lvm/%s.cfg >/dev/null
