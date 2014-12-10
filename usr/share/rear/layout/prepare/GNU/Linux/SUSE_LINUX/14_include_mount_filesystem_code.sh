# code to mount a file system 14_include_mount_filesystem_code.sh for SUSE_LINUX
# 13_mount_filesystem_code.sh contains the generic function 'mount_fs'
# each distro may overrule the 'mount_fs' function with its proper way to do it
# especially the case for btrfs related file systems

mount_fs() {
    local fs device mp fstype uuid label options
    ## mp: mount point
    read fs device mp fstype uuid label options < <(grep "^fs.* ${1#fs:} " "$LAYOUT_FILE")

    label=${label#label=}
    uuid=${uuid#uuid=}

    # Extract mount options
    local option mountopts
    for option in $options ; do
        name=${option%%=*}     # options can contain more '=' signs
        value=${option#*=}

        case $name in
            options)
                ### do not mount nodev, as chrooting later on would fail
                mountopts=${value//nodev/dev}
                ;;
        esac
    done

    if [ -n "$mountopts" ] ; then
        mountopts=" -o $mountopts"
    fi

    echo "LogPrint \"Mounting filesystem $mp\"" >> $LAYOUT_CODE

    case $fstype in
        btrfs)
          if test "/" != "$mp"
          then
            LogPrint "Skipping creating $fstype filesystem on $device because mountpoint $mp is not / (for SLE12 btrfs is only supported for /)"
          else
            # The below commands seems to be made for Fedora 19 (cf. https://github.com/rear/rear/issues/233)
            # but they do not work for SUSE SLE12 so that the following commands are hereby disabled:
            ## check the $value for subvols (other then root)
            #subvol=$(echo $value |  awk -F, '/subvol=/  { print $NF}') # empty or something like 'subvol=root'
            #if [ -z "$subvol" ]; then
            #    echo "mkdir -p /mnt/local$mp" >> $LAYOUT_CODE
            #    echo "mount$mountopts $device /mnt/local$mp" >> $LAYOUT_CODE
            #elif [ "$subvol" = "subvol=root" ]; then
            #    echo "# btrfs subvolume 'root' is a special case" >> $LAYOUT_CODE
            #    echo "# before we can create subvolumes we must mount a btrfs device on /mnt" >> $LAYOUT_CODE
            #    echo "mount | grep btrfs | grep -q '/mnt' || mount $device /mnt" >> $LAYOUT_CODE
            #    echo "# create the root btrfs subvolume" >> $LAYOUT_CODE
            #    echo "btrfs subvolume create /mnt/root" >> $LAYOUT_CODE
            #    echo "mkdir -p /mnt/local$mp" >> $LAYOUT_CODE
            #    echo "# umount subvol 0 as it will be remounted as /mnt/local" >> $LAYOUT_CODE
            #    echo "umount /mnt" >> $LAYOUT_CODE
            #    echo "mount$mountopts $device /mnt/local$mp" >> $LAYOUT_CODE
            #else
            #    echo "# btrfs subvolume creates sub-directory itself" >> $LAYOUT_CODE
            #    echo "btrfs subvolume create /mnt/local$mp" >> $LAYOUT_CODE
            #    # just mounting it with subvol=xxx will probably fail with an cryptic error:
            #    # mount: mount(2) failed: No such file or directory
            #    # we need to mount it with its subvol-id - not a joke
            #    # even its not yet mounted we can view it - see http://www.funtoo.org/BTRFS_Fun
            #    echo "btrfs_id=\$(btrfs subvolume list /mnt/local$mp | tail -1 | awk '{print \$2}')" >> $LAYOUT_CODE
            #    echo "mountopts=\" -o subvolid=\${btrfs_id}\"" >> $LAYOUT_CODE
            #    echo "mount\$mountopts $device /mnt/local$mp" >> $LAYOUT_CODE
            #fi
            # Instead commands that work for SUSE SLE12 are run:
            # When there are btrfs subvolumes $mountopts contains them in the form (cf. the example below) without the ':
            #   ' -o rw,relatime,space_cache,normalsubvolumes=/normalsubvolume;/basesubvolume;/basesubvolume/subsubvolume'
            # so that the btrfs subvolumes must be removed from $mountopts:
            realmountopts=$( echo $mountopts | sed -e 's/,normalsubvolumes=[^,]*//' )
            # In the example realmountopts is now '-o rw,relatime,space_cache' (no longer with a leading ' ').
            # The following two commands are basically the same (realmountopts versus mountopts) as in the default/fallback case:
            echo "mkdir -p /mnt/local$mp" >> $LAYOUT_CODE
            echo "mount -t btrfs $realmountopts $device /mnt/local$mp" >> $LAYOUT_CODE
            # Remember what the SLE12 installer does when installing the original system
            # when installing a SLE12 default system on one harddisk with btrfs
            # (see the comment in usr/share/rear/layout/save/GNU/Linux/23_filesystem_layout.sh):
            # -------------------------------------------------------------------------------------------------------
            # # grep -o 'Executing:"/sbin/btrfs.*' /var/log/YaST2/y2log-1
            # Executing:"/sbin/btrfs filesystem show"
            # Executing:"/sbin/btrfs subvolume create '/tmp/libstorage-9vKYd4/tmp-mp-IoBzwl/@'"
            # Executing:"/sbin/btrfs subvolume list '/tmp/libstorage-9vKYd4/tmp-mp-IoBzwl'"
            # Executing:"/sbin/btrfs subvolume set-default 257 '/tmp/libstorage-9vKYd4/tmp-mp-IoBzwl'"
            # Executing:"/sbin/btrfs subvolume create '/tmp/libstorage-9vKYd4/tmp-mp-YH5GVp/@/boot/grub2/i386-pc'"
            # ...
            # -------------------------------------------------------------------------------------------------------
            # This means that for SLE12 there is a mysterious '/@' btrfs subvolume created
            # (/sbin/btrfs subvolume create '/tmp/libstorage-9vKYd4/tmp-mp-IoBzwl/@')
            # that is then made the default btrfs subvolume
            # (/sbin/btrfs subvolume set-default 257 '/tmp/libstorage-9vKYd4/tmp-mp-IoBzwl').
            # This hidden '/@' btrfs subvolume is specific for SLE12 (it is not in openSUSE 13.1).
            # Therefore the following code works only for SLE12:
            echo "# Creating SLE12 specific '/@' btrfs subvolume" >> $LAYOUT_CODE
            echo "btrfs subvolume create /mnt/local/@" >> $LAYOUT_CODE
            echo "# Making the '/@' subvolume the default subvolume" >> $LAYOUT_CODE
            echo "# The '/@' subvolume is currently the only subvolume" >> $LAYOUT_CODE
            echo "# Get the ID of the '/@' subvolume to set it as default subvolume" >> $LAYOUT_CODE
            echo "subvolumeID=\$( btrfs subvolume list /mnt/local | head -n1 | cut -d ' ' -f2 )" >> $LAYOUT_CODE
            echo "# Set the '/@' subvolume as default subvolume using its subvolume ID" >> $LAYOUT_CODE
            echo "btrfs subvolume set-default \$subvolumeID /mnt/local" >> $LAYOUT_CODE
            # After the '/@' subvolume was set as default subvolume,
            # remount the btrfs filesystem where currently the filesystem toplevel is mounted at /mnt/local/
            # but now the '/@' default subvolume must be mounted at /mnt/local/:
            echo "# Remount the '/@' default subvolume at /mnt/local/" >> $LAYOUT_CODE
            echo "umount /mnt/local$mp" >> $LAYOUT_CODE
            echo "mount -t btrfs $realmountopts $device /mnt/local$mp" >> $LAYOUT_CODE
            # Recreate "normal" btrfs subvolumes (btrfs snapshot subvolumes have been excluded):
            # btrfs subvolumes can be nested, for example btrfs subvolumes could be like
            #   /subvolume
            #   /basesubvolume
            #   /basesubvolume/subsubvolume
            # The subvolumes in the above example would be provided as an option in $value of the form
            #   this=foo,normalsubvolumes=/subvolume;/basesubvolume;/basesubvolume/subsubvolume,that=bar
            # options in $value are separated by ',' and the subvolumes are separated by '=' and ';'
            # which will fail when there are subvolumes with ',' or '=' or ';' in its name
            # so that admins who use such characters for their subvolume names get hereby
            # an exercise in using failsafe names and/or how to fix quick and dirty code ;-)
            # The sorting makes sure that /basesubvolume comes before /basesubvolume/subsubvolume
            # so that /basesubvolume gets created before /basesubvolume/subsubvolume:
            normalsubvolumes=$( echo $value | grep -o 'normalsubvolumes=[^,]*' | cut -d '=' -f2 | tr ';' '\n' | sort )
            # In the example normalsubvolumes contains now "/basesubvolume\n/basesubvolume/subsubvolume\n/subvolume"
            if test -n "$normalsubvolumes"
            then echo "# Begin creating and mounting normal btrfs subvolumes..." >> $LAYOUT_CODE
                 for subvolume in $normalsubvolumes
                 do if test -n "$subvolume"
                    then 
                         # e.g. for "btrfs subvolume create /foo/bar/baz" /foo/bar/ must exist
                         # but "baz" must not exist because btrfs subvolume creates "baz" itself
                         # when "baz" already exists, it fails with "ERROR: '/foo/bar/baz' exists".
                         subvolumepath=${subvolume%/*}
                         if test -n "$subvolumepath"
                         then echo "# Creating '$subvolumepath' directory" >> $LAYOUT_CODE
                              echo "mkdir -p /mnt/local/$subvolumepath" >> $LAYOUT_CODE
                         fi
                         echo "# btrfs subvolume creates last (sub-)directory in '$subvolume' itself" >> $LAYOUT_CODE
                         echo "# Creating btrfs subvolume '$subvolume' as '@$subvolume'" >> $LAYOUT_CODE
                         echo "btrfs subvolume create /mnt/local/$subvolume" >> $LAYOUT_CODE
                         echo "# Creating '$subvolume' mountpoint" >> $LAYOUT_CODE
                         echo "mkdir -p /mnt/local/$subvolume" >> $LAYOUT_CODE
                         echo "# Mounting btrfs subvolume '@$subvolume' at '$subvolume' mountpoint" >> $LAYOUT_CODE
                         # Note that the subvolume path for the subvol mount option is relative to the toplevel subvolume
                         # and the toplevel subvolume is the default subvolume that was above set to /mnt/local:
                         echo "mount -t btrfs -o subvol=@$subvolume $realmountopts $device /mnt/local$subvolume" >> $LAYOUT_CODE
                    fi
                 done
                 echo "# End creating and mounting normal btrfs subvolumes." >> $LAYOUT_CODE
            fi
          fi
          ;;
        *)
            echo "mkdir -p /mnt/local$mp" >> $LAYOUT_CODE
            echo "mount$mountopts $device /mnt/local$mp" >> $LAYOUT_CODE
            ;;
    esac

}
