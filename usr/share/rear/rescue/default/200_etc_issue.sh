# 200_etc_issue.sh
#
# write out /etc/issue for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

cat >$ROOTFS_DIR/etc/issue <<EOF

$VERSION_INFO

EOF

[ -f /etc/issue ] && cat /etc/issue >> $ROOTFS_DIR/etc/issue
