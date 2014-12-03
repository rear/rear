# code to mount a file system
# 13_mount_filesystem_code.sh contains the generic function 'mount_fs'
# each distro may overrule the 'mount_fs' function with its proper way to do it
# especially the case for btrfs related file systems

mount_fs() {
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
            options)
                ### Do not mount nodev, as chrooting later on would fail.
                mountopts=${value//nodev/dev}
                ;;
        esac
    done

    if [ -n "$mountopts" ] ; then
        mountopts=" -o $mountopts"
    fi

    echo "LogPrint \"Mounting filesystem $mp\"" >> "$LAYOUT_CODE"

    case $fstype in
        btrfs)
            # Fedora generic btrfs mount code
            # check the $value for subvols (other then root)
            subvol=$(echo $value |  awk -F, '/subvol=/  { print $NF}') # empty or something like 'subvol=root'
            if [ -z "$subvol" ]; then
                echo "mkdir -p /mnt/local$mp" >> "$LAYOUT_CODE"
                echo "mount$mountopts $device /mnt/local$mp" >> "$LAYOUT_CODE"
            elif [ "$subvol" = "subvol=root" ]; then
                (
                echo "# btrfs subvolume 'root' is a special case"
                echo "# before we can create subvolumes we must mount a btrfs device on /mnt"
                echo "mount | grep btrfs | grep -q '/mnt' || mount $device /mnt"
                echo "# create the root btrfs subvolume"
                echo "btrfs subvolume create /mnt/root"
                echo "mkdir -p /mnt/local$mp"
                echo "# umount subvol 0 as it will be remounted as /mnt/local"
                echo "umount /mnt"
                echo "mount$mountopts $device /mnt/local$mp"
                ) >> "$LAYOUT_CODE"
            else
                (
                echo "# btrfs subvolume creates sub-directory itself"
                echo "btrfs subvolume create /mnt/local$mp"
                # just mounting it with subvol=xxx will probably fail with an cryptic error:
                # mount: mount(2) failed: No such file or directory
                # we need to mount it with its subvol-id - not a joke
                # even its not yet mounted we can view it - see http://www.funtoo.org/BTRFS_Fun
                echo "btrfs_id=\$(btrfs subvolume list /mnt/local$mp | tail -1 | awk '{print \$2}')"
                echo "mountopts=\" -o subvolid=\${btrfs_id}\""
                echo "mount\$mountopts $device /mnt/local$mp"
                ) >> "$LAYOUT_CODE"
            fi
            ;;
        *)
            (
            echo "mkdir -p /mnt/local$mp"
            echo "mount$mountopts $device /mnt/local$mp"
            ) >> "$LAYOUT_CODE"
            ;;
    esac

}
