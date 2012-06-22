# 00_create_symlinks.sh
#
# create some symlinks for Relax-and-Recover
#
#    Relax-and-Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax-and-Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax-and-Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#


ln -sf $v bin/init $ROOTFS_DIR/init >&2
ln -sf $v bin $ROOTFS_DIR/sbin >&2
ln -sf $v bash $ROOTFS_DIR/bin/sh >&2
ln -sf $v vi $ROOTFS_DIR/bin/vim >&2
ln -sf $v true $ROOTFS_DIR/bin/pam_console_apply >&2 # RH/Fedora with udev needs this
ln -sf $v ../bin $ROOTFS_DIR/usr/bin >&2
ln -sf $v ../bin $ROOTFS_DIR/usr/sbin >&2
ln -sf $v /proc/self/mounts $ROOTFS_DIR/etc/mtab >&2

if [[ -d $ROOTFS_DIR/etc/sysconfig/network-scripts ]]; then
    ln -sf $v /bin/true $ROOTFS_DIR/etc/sysconfig/network-scripts/net.hotplug >&2
fi
[[ -x /sbin/hwup ]] && ln -sf $v true $ROOTFS_DIR/sbin/hwup >&2 # SUSE with udev needs this

Log "Creating LVM binary symlinks"
lvmbins="lvchange lvconvert lvcreate lvdisplay lvextend lvmchange lvmdiskscan lvmsadc lvmsar lvreduce lvremove lvrename lvresize lvs lvscan pvchange pvresize pvck pvcreate pvdata pvdisplay pvmove pvremove pvs pvscan vgcfgbackup vgcfgrestore vgchange vgck vgconvert vgcreate vgdisplay vgexport vgextend vgimport vgmerge vgmknodes vgreduce vgremove vgrename vgs vgscan vgsplit"
for bin in $lvmbins; do
    ln -sf $v lvm $ROOTFS_DIR/bin/$bin >&2
done
