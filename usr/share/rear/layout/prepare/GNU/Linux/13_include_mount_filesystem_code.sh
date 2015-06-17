# code to mount a file system
# 13_mount_filesystem_code.sh contains the generic function 'mount_fs'
# each distro may overrule the 'mount_fs' function with its proper way to do it
# especially the case for btrfs related file systems

mount_fs() {
    Log "Begin mount_fs( $@ )"
    local fs device mp fstype uuid label options
    ## mp: mount point
    read fs device mp fstype uuid label options < <(grep "^fs.* ${1#fs:} " "$LAYOUT_FILE")

    label=${label#label=}
    uuid=${uuid#uuid=}

    # Extract mount options.
    local option mountopts
    for option in $options ; do
        name=${option%%=*}     # options can contain more '=' signs
        value=${option#*=}

        case $name in
            (options)
                ### Do not mount nodev, as chrooting later on would fail.
                mountopts=${value//nodev/dev}
                ;;
        esac
    done

    if [ -n "$mountopts" ] ; then
        mountopts="-o $mountopts"
    fi

    echo "LogPrint \"Mounting filesystem $mp\"" >> "$LAYOUT_CODE"

    case $fstype in
        (btrfs)
            # The following commands are basically the same as in the default/fallback case.
            # The explicite case for btrfs is only there to be prepared for special adaptions for btrfs related file systems.
            # Because the btrfs filesystem was created anew just before by the create_fs function in 13_include_filesystem_code.sh
            # the code here mounts the whole btrfs filesystem because by default when creating a btrfs filesystem
            # its top-level/root subvolume is the btrfs default subvolume which gets mounted when no other subvolume is specified.
            # For a plain btrfs filesystem without subvolumes it is effectively the same as for other filesystems (like ext2/3/4).
            (
            echo "mkdir -p /mnt/local$mp"
            echo "mount -t btrfs $mountopts $device /mnt/local$mp"
            ) >> "$LAYOUT_CODE"
            # But btrfs filesystems with subvolumes need a special handling.
            # In particular when in the original system the btrfs filesystem had a special different default subvolume,
            # that different subvolume needs to be first created, then set to be the default subvolume, and
            # finally that btrfs filesystem needs to be unmounted and mounted again so that in the end
            # that special different default subvolume is mounted at the mountpoint /mnt/local$mp.
            # All btrfs subvolume handling happens in the btrfs_subvolumes_setup function in 13_include_mount_subvolumes_code.sh
            # For a plain btrfs filesystem without subvolumes the btrfs_subvolumes_setup function does nothing.
            # Call the btrfs_subvolumes_setup function for the btrfs filesystem that was mounted above:
            btrfs_subvolumes_setup $device $mp $mountopts
            ;;
        (vfat)
            # mounting vfat filesystem - avoid using mount options - issue #576
            (
            echo "mkdir -p /mnt/local$mp"
            echo "mount $device /mnt/local$mp"
            ) >> "$LAYOUT_CODE"
            ;;
        (*)
            (
            echo "mkdir -p /mnt/local$mp"
            echo "mount $mountopts $device /mnt/local$mp"
            ) >> "$LAYOUT_CODE"
            ;;
    esac

    # Return successfully:
    Log "End mount_fs( $@ )"
    true
}

