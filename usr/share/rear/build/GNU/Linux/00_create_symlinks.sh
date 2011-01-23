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

pushd $ROOTFS_DIR >/dev/null
	
	ln -sfv bin/init init 1>&2
	ln -sfv bin sbin 1>&2
	pushd bin >/dev/null
		ln -sfv bash sh 1>&2
		ln -sfv true pam_console_apply 1>&2 # RH/Fedora with udev needs this
	popd >/dev/null
	pushd usr >/dev/null
		ln -sfv /bin bin 1>&2
		ln -sfv /lib lib 1>&2
	popd >/dev/null
	ln -sfv /bin/true etc/sysconfig/network-scripts/net.hotplug 1>&2
popd >/dev/null
