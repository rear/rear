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
    # An input line could look like this (an example from SLES12-SP1):
    # fs /dev/sda2 / btrfs uuid=a2b2c3 label= options=rw,relatime,space_cache,subvolid=259,subvol=/@/.snapshots/1/snapshot
    # which means by the above 'read' the variable (that is unfortunately) named 'options' gets the
    # value 'options=rw,relatime,space_cache,subvolid=259,subvol=/@/.snapshots/1/snapshot'
    # i.e. options='options=rw,relatime,space_cache,subvolid=259,subvol=/@/.snapshots/1/snapshot'
    for option in $options ; do
        name=${option%%=*}     # an option can contain more '=' signs (see the above example value)
        value=${option#*=}     # therefore split the name from the actual value at the leftmost '='

        case $name in
            (options)
                ### Do not mount nodev, as chrooting later on would fail.
                value=${value//nodev/dev}
                # btrfs mount options like subvolid=259 or subvol=/@/.snapshots/1/snapshot
                # from the old system cannot work here for recovery because btrfs subvolumes
                # are not yet created (and when created their subvolid is likely different)
                # so that those mount options are removed here. All btrfs subvolume handling
                # happens in the btrfs_subvolumes_setup function in 13_include_mount_subvolumes_code.sh
                # First add a comma at the end so that it is easier to remove a mount option at the end:
                value=${value/%/,}
                # Remove all subvolid= and subvol= mount options (the extglob shell option is enabled in rear):
                value=${value//subvolid=*([^,]),/}
                value=${value//subvol=*([^,]),/}
                # Remove all commas at the end:
                mountopts=${value/%,/}
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

