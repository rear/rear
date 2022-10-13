# This file is part of Relax-and-Recover,
# licensed under the GNU General Public License.
# Refer to the included COPYING for full text of license.

# Skip it when the user has explicitly specified to not use barrel:
is_false "$BARREL_DEVICEGRAPH" && return 0

# Skip it when there is no 'barrel' program
# but error out when the user has explicitly specified to use barrel:
if has_binary barrel ; then
    LogPrint "Also saving storage layout as 'barrel' devicegraph"
else
    is_true "$BARREL_DEVICEGRAPH" && Error "Cannot find 'barrel' command (BARREL_DEVICEGRAPH is 'true')"
    DebugPrint "Skip saving storage layout as 'barrel' devicegraph (no 'barrel' command)"
    return 0
fi

BARREL_DEVICEGRAPH_DIR="$VAR_DIR/layout/barrel"
mkdir -p $v $BARREL_DEVICEGRAPH_DIR

# Let barrel save the whole storage layout (as a devicegraph):
BARREL_DEVICEGRAPH_FILE=$BARREL_DEVICEGRAPH_DIR/devicegraph.xml
if barrel $v save devicegraph --name $BARREL_DEVICEGRAPH_FILE 0<&6 1>&7 2>&8 ; then
    DebugPrint "Saved 'barrel' devicegraph in $BARREL_DEVICEGRAPH_FILE"
else
    is_true "$BARREL_DEVICEGRAPH" && Error "barrel failed to save devicegraph in $BARREL_DEVICEGRAPH_FILE (BARREL_DEVICEGRAPH is 'true')"
    LogPrintError "barrel failed to save devicegraph' in $BARREL_DEVICEGRAPH_FILE"
    return 1
fi

# When 'barrel save devicegraph' succeeded
# include all possibly needed programs to recreate the storage layout during "rear recover":

# barrel requires getconf otherwise it fails with
#   Probing...error: Command not found: "/usr/bin/getconf PAGESIZE"
REQUIRED_PROGS+=( barrel getconf )

# barrel uses libstorage-ng which can call the following programs, see
# https://github.com/openSUSE/libstorage-ng/blob/master/storage/Utils/StorageDefines.h
# In a libstorage-ng sources directory run (here for libstorage-ng-4.4.17)
# # grep -o 'bin/[^"]*' storage/Utils/StorageDefines.h | cut -d '/' -f2-
#  sh echo cat uname getconf
#  parted
#  mdadm
#  pvcreate pvremove pvresize pvs lvcreate lvremove lvresize lvchange lvs vgcreate vgremove vgextend vgreduce vgs vgchange
#  cryptsetup
#  multipath multipathd
#  dmsetup dmraid
#  btrfs
#  wipefs
#  bcache
#  mount umount
#  swapon swapoff
#  dd
#  blkid lsscsi
#  ls df test stat
#  losetup
#  lsattr chattr
#  dasdview
#  udevadm rpcbind efibootmgr
#  ntfsresize xfs_growfs resize_reiserfs resize2fs fatresize tune2fs reiserfstune xfs_admin jfs_tune
#  ntfslabel fatlabel swaplabel exfatlabel
#  dumpe2fs
#  mkswap
#  mkfs.xfs mkfs.jfs mkfs.fat mkfs.ntfs mkreiserfs mke2fs mkfs.btrfs mkfs.f2fs mkfs.exfat mkfs.udf
#  dot display
# We include all of them if they are installed
# except getconf that is already in REQUIRED_PROGS above
# and except generic programs like sh echo cat uname parted mount umount dd ls df test stat
# and except dot and display which are programs for drawing graphs and display images on an X server:
PROGS+=( mdadm
         pvcreate pvremove pvresize pvs lvcreate lvremove lvresize lvchange lvs vgcreate vgremove vgextend vgreduce vgs vgchange
         cryptsetup
         multipath multipathd
         dmsetup dmraid
         btrfs
         wipefs
         bcache
         swapon swapoff
         blkid lsscsi
         losetup
         lsattr chattr
         dasdview
         udevadm rpcbind efibootmgr
         ntfsresize xfs_growfs resize_reiserfs resize2fs fatresize tune2fs reiserfstune xfs_admin jfs_tune
         ntfslabel fatlabel swaplabel exfatlabel
         dumpe2fs
         mkswap
         mkfs.xfs mkfs.jfs mkfs.fat mkfs.ntfs mkreiserfs mke2fs mkfs.btrfs mkfs.f2fs mkfs.exfat mkfs.udf )

