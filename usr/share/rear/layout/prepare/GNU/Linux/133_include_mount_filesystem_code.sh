# code to mount a file system
# 130_mount_filesystem_code.sh contains the generic function 'mount_fs'
# each distro may overrule the 'mount_fs' function with its proper way to do it
# especially the case for btrfs related file systems

mount_fs() {
    Log "Begin mount_fs( $@ )"
    local fs device mountpoint fstype uuid label attributes
    read fs device mountpoint fstype uuid label attributes < <(grep "^fs.* ${1#fs:} " "$LAYOUT_FILE")

    label=${label#label=}
    uuid=${uuid#uuid=}

    # Extract mount options:
    local attribute mountopts
    # An input line could look like this (an example from SLES12-SP1):
    #   Format: fs <device> <mountpoint> <fstype> [uuid=<uuid>] [label=<label>] [<attributes>]
    #   fs /dev/sda2 / btrfs uuid=a2b2c3 label= options=rw,relatime,space_cache,subvolid=259,subvol=/@/.snapshots/1/snapshot
    # For example the attributes variable can contain a value like:
    #   "reserved_blocks=5% max_mounts=-1 default_mount_options=user_xattr,acl options=rw,relatime,barrier=1,data=ordered"
    # I.e. the attributes variable can contain several attributes separated by space each of the form name=value.
    for attribute in $attributes ; do
        # An attribute can contain more '=' signs (see the above "options=foo,this=that,..." example values)
        # therefore split the name from the actual value at the leftmost '='
        # (e.g. name="options" value="rw,relatime,space_cache,subvolid=259,subvol=/@/.snapshots/1/snapshot"):
        name=${attribute%%=*}
        value=${attribute#*=}
        # The attribute with name "options" contains the mount options:
        case $name in
            (options)
                # Do not mount nodev, as chrooting later on would fail:
                # FIXME: naive approach, will replace any "nodev" inside longer options/values
                value=${value//nodev/dev}
                # btrfs mount options like subvolid=259 or subvol=/@/.snapshots/1/snapshot
                # from the old system cannot work here for recovery because btrfs subvolumes
                # are not yet created (and when created their subvolid is likely different)
                # so that those mount options are removed here. All btrfs subvolume handling
                # happens in the btrfs_subvolumes_setup_SLES function in 136_include_btrfs_subvolumes_SLES_code.sh
                # or in the btrfs_subvolumes_setup_generic function in 135_include_btrfs_subvolumes_generic_code.sh
                # Remove all subvolid= and subvol= mount options:
                mountopts="$( remove_mount_options_values $value subvolid subvol )"
                ;;
        esac
    done

    if [ -n "$mountopts" ] ; then
        mountopts="-o $mountopts"
    fi

    echo "LogPrint \"Mounting filesystem $mountpoint\"" >> "$LAYOUT_CODE"

    case $fstype in
        (btrfs)
            # The following commands are basically the same as in the default/fallback case.
            # The explicit case for btrfs is only there to be prepared for special adaptions for btrfs related file systems.
            # Because the btrfs filesystem was created anew just before by the create_fs function in 131_include_filesystem_code.sh
            # the code here mounts the whole btrfs filesystem because by default when creating a btrfs filesystem
            # its top-level/root subvolume is the btrfs default subvolume which gets mounted when no other subvolume is specified.
            # For a plain btrfs filesystem without subvolumes it is effectively the same as for other filesystems (like ext2/3/4).
            (
            echo "mkdir -p $TARGET_FS_ROOT$mountpoint"
            echo "mount -t btrfs $mountopts $device $TARGET_FS_ROOT$mountpoint"
            ) >> "$LAYOUT_CODE"
            # But btrfs filesystems with subvolumes need a special handling.
            # In particular when in the original system the btrfs filesystem had a special different default subvolume,
            # that different subvolume needs to be first created, then set to be the default subvolume, and
            # finally that btrfs filesystem needs to be unmounted and mounted again so that in the end
            # that special different default subvolume is mounted at the mountpoint $TARGET_FS_ROOT$mountpoint.
            # All btrfs subvolume handling happens in the btrfs_subvolumes_setup_SLES function in 136_include_btrfs_subvolumes_SLES_code.sh
            # or in the btrfs_subvolumes_setup_generic function in 135_include_btrfs_subvolumes_generic_code.sh.
            # For a plain btrfs filesystem without subvolumes the btrfs_subvolumes_setup_* functions do nothing.
            # Call the right btrfs_subvolumes_setup_* function for the btrfs filesystem that was mounted above via an
            # artificial 'for' clause that is run only once to be able to 'continue' with the code after it:
            for dummy in "once" ; do
                # First of all test what is explicitly specified to be done for particular devices because
                # what is explicitly specified for a particular device must be done with highest priority:
                if IsInArray "$device" "${BTRFS_SUBVOLUME_GENERIC_SETUP[@]}" ; then
                    LogPrint "Doing generic btrfs subvolumes setup for $device on $mountpoint (BTRFS_SUBVOLUME_GENERIC_SETUP contains $device)"
                    btrfs_subvolumes_setup_generic $device $mountpoint
                    continue
                fi
                if IsInArray "$device" "${BTRFS_SUBVOLUME_SLES_SETUP[@]}" ; then
                    LogPrint "Doing SLES-like btrfs subvolumes setup for $device on $mountpoint (BTRFS_SUBVOLUME_SLES_SETUP contains $device)"
                    btrfs_subvolumes_setup_SLES $device $mountpoint $mountopts
                    continue
                fi
                # Then test what is explicitly specified to be done globally (i.e. for all devices)
                # where doing a generic btrfs subvolumes setup has precedence over doing a SLES-like btrfs subvolumes setup so that
                # when both BTRFS_SUBVOLUME_GENERIC_SETUP and BTRFS_SUBVOLUME_SLES_SETUP are true, the generic one is done:
                if is_true "$BTRFS_SUBVOLUME_GENERIC_SETUP" ; then
                    LogPrint "Doing generic btrfs subvolumes setup for $device on $mountpoint (BTRFS_SUBVOLUME_GENERIC_SETUP true)"
                    btrfs_subvolumes_setup_generic $device $mountpoint
                    continue
                fi
                if is_true "$BTRFS_SUBVOLUME_SLES_SETUP" ; then
                    LogPrint "Doing SLES-like btrfs subvolumes setup for $device on $mountpoint (BTRFS_SUBVOLUME_SLES_SETUP true)"
                    btrfs_subvolumes_setup_SLES $device $mountpoint $mountopts
                    continue
                fi
                # Then test if it is explicitly specified to do nothing at all.
                # When both BTRFS_SUBVOLUME_GENERIC_SETUP and BTRFS_SUBVOLUME_SLES_SETUP are explicitly set to false
                # no special btrfs subvolumes setup is done which may lead to a falsely recreated system
                # but we do what the user has explicitly specified:
                if is_false "$BTRFS_SUBVOLUME_GENERIC_SETUP" && is_false "$BTRFS_SUBVOLUME_SLES_SETUP" ; then
                    LogPrint "Skipping btrfs subvolumes setup for $device on $mountpoint (BTRFS_SUBVOLUME_GENERIC_SETUP and BTRFS_SUBVOLUME_SLES_SETUP false)"
                    continue
                fi
                # Then test if it is explicitly specified to not do a certain kind of btrfs subvolumes setup
                # i.e. the meaning when one kind of btrfs subvolumes setup is set to false is
                # that then the other kind of btrfs subvolumes setup should be done
                # (unless both are set to false which was already tested before):
                if is_false "$BTRFS_SUBVOLUME_GENERIC_SETUP" ; then
                    LogPrint "Doing SLES-like btrfs subvolumes setup for $device on $mountpoint (BTRFS_SUBVOLUME_GENERIC_SETUP false)"
                    btrfs_subvolumes_setup_SLES $device $mountpoint $mountopts
                    continue
                fi
                if is_false "$BTRFS_SUBVOLUME_SLES_SETUP" ; then
                    LogPrint "Doing generic btrfs subvolumes setup for $device on $mountpoint (BTRFS_SUBVOLUME_SLES_SETUP false)"
                    btrfs_subvolumes_setup_generic $device $mountpoint
                    continue
                fi
                # Final fallback to be backward compatible (btrfs_subvolumes_setup_SLES is the old way) when nothing is specified:
                LogPrint "Fallback SLES-like btrfs subvolumes setup for $device on $mountpoint (no match in BTRFS_SUBVOLUME_GENERIC_SETUP or BTRFS_SUBVOLUME_SLES_SETUP)"
                btrfs_subvolumes_setup_SLES $device $mountpoint $mountopts
            done
            ;;
        (vfat)
            # mounting vfat filesystem - avoid using mount options - issue #576
            (
            echo "mkdir -p $TARGET_FS_ROOT$mountpoint"
            echo "mount $device $TARGET_FS_ROOT$mountpoint"
            ) >> "$LAYOUT_CODE"
            ;;
        (ext2 | ext3 | ext4)
            (
            echo "mkdir -p $TARGET_FS_ROOT$mountpoint"
            echo "mount $mountopts $device $TARGET_FS_ROOT$mountpoint"
            # try remount for xattr
            # mount and then try remount for systems supporting xattr
            # add a second mount for extended attr (selinux) 
            # the first mount will do perform the basic mount, the second mount (remount) will try for xattr
            # if xattr are not support, the mount will fail, however, the first mount will still be in effect and not cause any errors
            echo "mount $mountopts,remount,user_xattr $device $TARGET_FS_ROOT$mountpoint"
            ) >> "$LAYOUT_CODE"
            ;;
        (xfs)
            # remove logbsize=... mount option. It is a purely performance/memory usage optimization option,
            # which can lead to mount failures, because it must be an integer multiple of the log stripe unit
            # and the log stripe unit can be different in the recreated filesystem from the original filesystem
            # (for example when using MKFS_XFS_OPTIONS, or in some exotic situations involving an old filesystem,
            # see GitHub issue #2777 ).
            # If logbsize is not an integer multiple of the log stripe unit, mount fails with the warning
            # "XFS (...): logbuf size must be greater than or equal to log stripe size"
            # in the kernel log
            # (and a confusing error message
            # "mount: ...: wrong fs type, bad option, bad superblock on ..., missing codepage or helper program, or other error."
            # from the mount command), causing the layout restoration in the recovery process to fail.
            # Wrong sunit/swidth can cause mount to fail as well, with this in the kernel log:
            # "kernel: XFS (...): alignment check failed: sunit/swidth vs. agsize",
            # so remove the sunit=.../swidth=... mount options as well.
            mountopts="$( remove_mount_options_values "$mountopts" logbsize sunit swidth )"
            (
            echo "mkdir -p $TARGET_FS_ROOT$mountpoint"
            echo "mount $mountopts $device $TARGET_FS_ROOT$mountpoint"
            ) >> "$LAYOUT_CODE"
            ;;
        (*)
            (
            echo "mkdir -p $TARGET_FS_ROOT$mountpoint"
            echo "mount $mountopts $device $TARGET_FS_ROOT$mountpoint"
            ) >> "$LAYOUT_CODE"
            ;;
    esac

    # Return successfully:
    Log "End mount_fs( $@ )"
    true
}

