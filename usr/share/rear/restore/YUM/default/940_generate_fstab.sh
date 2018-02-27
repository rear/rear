#
# restore/YUM/default/940_generate_fstab.sh
# 940_generate_fstab.sh is a finalisation script (see restore/readme)
# that generates etc/fstab in the target system
# according to what of the target system is currently mounted.
# Generating etc/fstab in the target system is needed as prerequirement
# for making a valid initrd via finalize/SUSE_LINUX/i386/170_rebuild_initramfs.sh
# otherwise when booting the recreated system the kernel panics
# with 'unable to mount root fs'
#

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

# Determine system partition and swap partition
# from what is in LAYOUT_FILE (usually var/lib/rear/layout/disklayout.conf).
local keyword device_node mountpoint filesystem_type junk
pushd /dev/disk/by-uuid/ 1>&2
# Ensure file name generation (globbing) is enabled (needed below in 'for uuid in *'):
set +f
# Write swap entries to etc/fstab in the target system:
# Format of swap partitions or swap files in LAYOUT_FILE:
# swap <filename> uuid=<uuid> label=<label>
# e.g.
# swap /dev/sda1 uuid=28e43119-dac1-4426-a71a-1d70b26d33d7 label=
while read keyword device_node junk ; do
    test "$device_node" || Error "No device node in $LAYOUT_FILE for '$keyword [no device node] $junk'"
    # Do not use a possibly outdated UUID from LAYOUT_FILE but determine the actual one in the current system:
    uuid=$( for uuid in * ; do readlink -e $uuid | grep -q $device_node && echo $uuid || true ; done  )
    # If fstab already contains an entry for this swap device, do nothing
    if egrep -q "^UUID=$uuid\s+swap" $TARGET_FS_ROOT/etc/fstab || egrep -q "^$device_node\s+swap" $TARGET_FS_ROOT/etc/fstab ; then
        LogPrint "Skipping addition of swap device $device_node (UUID=$uuid) - already in etc/fstab of the target system"
	continue
    fi
    # One cannot rely on that swap partitions are in use in the recovery system
    # so that as fallback the device node is set in etc/fstab in the target system:
    if test "$uuid" ; then
        echo "UUID=$uuid swap swap defaults 0 0" >>$TARGET_FS_ROOT/etc/fstab
        LogPrint "Wrote 'UUID=$uuid swap swap defaults 0 0' to etc/fstab in the target system"
    else
        LogPrint "Instead of UUID using plain device node '$device_node' for swap in /etc/fstab as fallback, check $TARGET_FS_ROOT/etc/fstab before rebooting"
        echo "$device_node swap swap defaults 0 0" >>$TARGET_FS_ROOT/etc/fstab
        LogPrint "Wrote '$device_node swap swap defaults 0 0' to etc/fstab in the target system"
    fi
done < <( grep "^swap " "$LAYOUT_FILE" )
# Write filesystem entries to etc/fstab in the target system:
# Format of filesystem entries in LAYOUT_FILE:
# fs <device> <mountpoint> <fstype> [uuid=<uuid>] [label=<label>] [<attributes>]
# e.g.
# fs /dev/sda2 / ext4 uuid=46d7e8be-7812-49d1-8d24-e25ed0589e94 label= blocksize=4096 ... default_mount_options=user_xattr,acl options=rw,relatime,data=ordered
# FIXME: add support for default_mount_options in /etc/fstab (instead of only 'defaults')
while read keyword device_node mountpoint filesystem_type junk ; do
    test "$device_node" || Error "No device node in $LAYOUT_FILE for '$keyword [no device node] $mountpoint $filesystem_type $junk'"
    test "$mountpoint" || Error "No mountpoint in $LAYOUT_FILE for '$keyword $device_node [no mountpoint] $filesystem_type $junk'"
    test "$filesystem_type" || Error "No filesystem type in $LAYOUT_FILE for '$keyword $device_node $mountpoint [no filesystem type] $junk'"
    # Do not use a possibly outdated UUID from LAYOUT_FILE but determine the actual one in the current system:
    uuid=$( for uuid in * ; do readlink -e $uuid | grep -q $device_node && echo $uuid || true ; done  )
    # If fstab already contains an entry for this filesystem, do nothing
    if egrep -q "^UUID=$uuid\s+$mountpoint" $TARGET_FS_ROOT/etc/fstab || egrep -q "^$device_node\s+$mountpoint" $TARGET_FS_ROOT/etc/fstab ; then
        LogPrint "Skipping addition of swap device $device_node (UUID=$uuid) - already in etc/fstab of the target system"
	continue
    fi
    # Regardless that all active filesystems in LAYOUT_FILE should be in use in the recovery system
    # do not abort but use as fallback the device node is set in etc/fstab in the target system:
    if test "$uuid" ; then
        echo "UUID=$uuid $mountpoint $filesystem_type defaults 0 0" >>$TARGET_FS_ROOT/etc/fstab
        LogPrint "Wrote 'UUID=$uuid $mountpoint $filesystem_type defaults 0 0' to etc/fstab in the target system"
    else
        LogPrint "Instead of UUID using plain device node '$device_node' for '$mountpoint' in /etc/fstab as fallback, check $TARGET_FS_ROOT/etc/fstab before rebooting"
        echo "$device_node $mountpoint $filesystem_type defaults 0 0" >>$TARGET_FS_ROOT/etc/fstab
        LogPrint "Wrote '$device_node $mountpoint $filesystem_type defaults 0 0' to etc/fstab in the target system"
    fi
done < <( grep "^fs " "$LAYOUT_FILE" )
popd 1>&2

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"

