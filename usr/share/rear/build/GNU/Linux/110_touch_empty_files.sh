# 100_touch_empty_files.sh
#
# Create some empty system necessary files for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

pushd $ROOTFS_DIR >/dev/null
	touch var/log/lastlog
	touch var/lib/nfs/state
	touch etc/mtab
	touch etc/udev/rules.d/65-md-incremental.rules
popd >/dev/null
