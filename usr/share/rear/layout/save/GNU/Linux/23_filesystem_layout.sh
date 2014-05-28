# Save Filesystem layout

Log "Saving Filesystem layout."

(
    # Filesystems
    # format: fs <device> <mountpoint> <filesystem> [uuid=<uuid>] [label=<label>] [<attributes>]
    while read device on mountpoint type fstype options junk; do
        if [ "${device#/}" = "$device" ] ; then
            continue
        fi

        if [ ! -b "$device" ] ; then
            Log "$device is not a block device, skipping."
            continue
        fi
        if [ "$fstype" = "iso9660" ] ; then
            Log "$device is CD/DVD type device [$fstype], skipping."
            continue
        fi

        if [[ $device == /dev/disk/by-uuid* ]]; then
          ndevice=$(readlink -f $device)
          Log "Mapping $device to $ndevice"
          device=$ndevice
        fi

        echo -n "fs $device $mountpoint $fstype "
        case "$fstype" in
            ext*)
                tunefs="tune2fs"
                # on RHEL 5 tune2fs does not work on ext4, needs tune4fs
                if [ "$fstype" = "ext4" ] ; then
                    if ! tune2fs -l $device >&8; then
                        tunefs="tune4fs"
                    fi
                fi

                uuid=$($tunefs -l $device | grep UUID | cut -d ":" -f 2 | tr -d " ")
                label=$(e2label $device)

                # options: blocks, fragments, max_mount, check_interval, reserved blocks, bytes_per_inode
                blocksize=$($tunefs -l $device | grep "Block size" | tr -d " " | cut -d ":" -f "2")
                max_mounts=$($tunefs -l $device | grep "Maximum mount count" | tr -d " " | cut -d ":" -f "2")
                check_interval=$($tunefs -l $device | grep "Check interval" | cut -d "(" -f 1 | tr -d " " | cut -d ":" -f "2")

                nr_blocks=$($tunefs -l $device | grep "Block count" | tr -d " " | cut -d ":" -f "2")
                reserved_blocks=$($tunefs -l $device | grep "Reserved block count" | tr -d " " | cut -d ":" -f "2")
                reserved_percentage=$(( reserved_blocks * 100 / nr_blocks ))

                nr_inodes=$($tunefs -l $device | grep "Inode count" | tr -d " " | cut -d ":" -f "2")
                let "bytes_per_inode=$nr_blocks*$blocksize/$nr_inodes"

                default_mount_options=$(tune2fs -l $device | grep -i "Default mount options" | cut -d ":" -f "2" | awk '{$1=$1};1' | tr ' ' ',' | grep -v none)

                # translate check_interval from seconds to days
                let check_interval=$check_interval/86400

                echo -n "uuid=$uuid label=$label"
                echo -n " blocksize=$blocksize reserved_blocks=$reserved_percentage%"
                echo -n " max_mounts=$max_mounts check_interval=${check_interval}d"
                echo -n " bytes_per_inode=$bytes_per_inode"
                if [[ -n $default_mount_options ]]; then
                    echo -n " default_mount_options=$default_mount_options"
                fi
                ;;
            vfat)
                # Make sure we don't get any other output from dosfslabel (errors go to stdout :-/)
                label=$(dosfslabel $device | tail -1)
		uuid=$(blkid_uuid_of_device $device)
                echo -n " uuid=$uuid label=$label"
                ;;
            xfs)
                uuid=$(xfs_admin -u $device | cut -d'=' -f 2 | tr -d " ")
                label=$(xfs_admin -l $device | cut -d'"' -f 2)
                echo -n "uuid=$uuid label=$label "
                ;;
            reiserfs)
                uuid=$(debugreiserfs $device | grep "UUID" | cut -d":" -f "2" | tr -d " ")
                label=$(debugreiserfs $device | grep "LABEL" | cut -d":" -f "2" | tr -d " ")
                echo -n "uuid=$uuid label=$label"
                ;;
            btrfs)
                uuid=$(btrfs filesystem show $device | grep -i "uuid:" | cut -d":" -f "3" | tr -d " ")
                label=$(btrfs filesystem show $device | grep -i label | cut -d":" -f "2" | sed -e 's/uuid//' -e 's/^ //')
                [[ "$(echo $label)" = "none" ]] && label=
                echo -n "uuid=$uuid label=$label"
                ;;
        esac

        options=${options#(}
        options=${options%)}

	# in case of btrfs we could deal with subvolumes - subvol option needed or not?
	case "$fstype" in
	    btrfs)
		subvol=$(btrfs subvolume show $mountpoint | grep "Name:" | awk '{print $2}')
		[[ ! -z "$subvol" ]] && options="$options,subvol=$subvol"
		;;
	esac
        echo -n " options=$options"
        echo
    done < <(mount)
) >> $DISKLAYOUT_FILE
