# 005_create_symlinks.sh
#
# create some symlinks for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

ln -sf $v bin/init $ROOTFS_DIR/init >&2
ln -sf $v bin $ROOTFS_DIR/sbin >&2
ln -sf $v bash $ROOTFS_DIR/bin/sh >&2
ln -sf $v true $ROOTFS_DIR/bin/pam_console_apply >&2 # RH/Fedora with udev needs this
ln -sf $v ../bin $ROOTFS_DIR/usr/bin >&2
ln -sf $v ../bin $ROOTFS_DIR/usr/sbin >&2
ln -sf $v /proc/self/mounts $ROOTFS_DIR/etc/mtab >&2

if [[ -d $ROOTFS_DIR/etc/sysconfig/network-scripts ]]; then
    ln -sf $v /bin/true $ROOTFS_DIR/etc/sysconfig/network-scripts/net.hotplug >&2
fi
[[ -x /sbin/hwup ]] && ln -sf $v true $ROOTFS_DIR/sbin/hwup >&2 # SUSE with udev needs this

# Only create LVM symlinks when the HOST system contains LVM
if hash lvm 2>/dev/null; then
    Log "Creating LVM binary symlinks"
    lvmbins="lvchange lvconvert lvcreate lvdisplay lvextend lvmchange lvmdiskscan lvmsadc lvmsar lvreduce lvremove lvrename lvresize lvs lvscan pvchange pvresize pvck pvcreate pvdata pvdisplay pvmove pvremove pvs pvscan vgcfgbackup vgcfgrestore vgchange vgck vgconvert vgcreate vgdisplay vgexport vgextend vgimport vgmerge vgmknodes vgreduce vgremove vgrename vgs vgscan vgsplit"
    for bin in $lvmbins; do
        ln -sf $v lvm $ROOTFS_DIR/bin/$bin >&2
    done
fi
