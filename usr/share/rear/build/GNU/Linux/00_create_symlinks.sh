# 00_create_symlinks.sh
#
# create some symlinks for Relax & Recover
#
#    Relax & Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax & Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax & Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#


ln -sfv bin/init $ROOTFS_DIR/init 1>&2
ln -sfv bin $ROOTFS_DIR/sbin  1>&2
ln -sfv bash $ROOTFS_DIR/bin/sh  1>&2
ln -sfv true $ROOTFS_DIR/bin/pam_console_apply  1>&2 # RH/Fedora with udev needs this
ln -sfv ../bin $ROOTFS_DIR/usr/bin  1>&2
ln -sfv ../bin $ROOTFS_DIR/usr/sbin 1>&2
ln -sfv /proc/self/mounts $ROOTFS_DIR/etc/mtab 1>&2
test -d $ROOTFS_DIR/etc/sysconfig/network-scripts && ln -sfv /bin/true $ROOTFS_DIR/etc/sysconfig/network-scripts/net.hotplug  1>&2
