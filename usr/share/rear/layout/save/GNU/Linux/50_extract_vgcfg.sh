# Use vgcfgbackup to copy the current LVM setup exactly

if ! type -p lvm &>/dev/null ; then
    return
fi

mkdir -p $VAR_DIR/layout/lvm
lvm 8>&- 7>&- vgcfgbackup -f $VAR_DIR/layout/lvm/%s.cfg > /dev/null
