# 10_touch_empty_files.sh
#
# Create some empty system necessary files for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

pushd $ROOTFS_DIR >&8
	touch var/log/lastlog
	touch var/lib/nfs/state
	touch etc/mtab
popd >&8
