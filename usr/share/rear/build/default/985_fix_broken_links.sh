
# build/default/985_fix_broken_links.sh
#
# Check for broken symbolic links inside the recovery system in ROOTFS_DIR
# and add missing symlink targets to the recovery system,
# see https://github.com/rear/rear/issues/1638
# and https://github.com/rear/rear/pull/1734

# FIXME: The following code fails if symlinks or their targets contain characters from IFS (e.g. blanks),
# cf. the same kind of comments in build/default/990_verify_rootfs.sh
# and layout/prepare/GNU/Linux/130_include_mount_subvolumes_code.sh
# see https://github.com/rear/rear/pull/1514#discussion_r141031975
# and for the general issue see https://github.com/rear/rear/issues/1372

# Find broken symbolic links inside the recovery system via 'chroot $ROOTFS_DIR find / -xtype l'
# (but exclude the special proc sys dev directories inside the recovery system)
# because 'pushd $ROOTFS_DIR ; find . -xtype l ; popd' would not find symlinks that are broken
# within the recovery system because the symlink target is outside of the recovery system,
# for example $ROOTFS_DIR/etc/localtime -> /usr/share/zoneinfo/Europe/Berlin is broken
# and should be $ROOTFS_DIR/etc/localtime -> $ROOTFS_DIR/usr/share/zoneinfo/Europe/Berlin
# cf. https://github.com/rear/rear/pull/1734#issuecomment-434635175
local broken_symlinks=$( chroot $ROOTFS_DIR find / -xdev -path '/proc' -prune -o -path '/sys' -prune -o -path '/dev' -prune -o -xtype l -print )

# Copy missing symlink targets into the recovery system if the symlink target exists
# (except the symlink target is in /proc/ /sys/ /dev/ or /run/).
# Otherwise report that there is something wrong on the original system and
# assume when things work sufficiently on the original system nevertheless
# this is no sufficient reason to abort here (i.e. proceed "bona fide")
# cf. what is done when '$lib is a symbolic link' in build/GNU/Linux/390_copy_binaries_libraries.sh
pushd $ROOTFS_DIR
    local broken_symlink=''
    local link_target=''
    for broken_symlink in $broken_symlinks ; do
        # If in the original system there was a chain of symbolic links like
        #   /some/path/to/file1 -> /another/path/to/file2 -> /final/path/to/file3
        # where $broken_symlink='/some/path/to/file1' and $link_target='/final/path/to/file3'
        # the chain of symbolic links gets simplified in the recovery system to $broken_symlink -> $link_target like
        #   /some/path/to/file1 -> /final/path/to/file3
        link_target=$( readlink $v -e $broken_symlink )
        if [[ "$link_target" != /* ]]; then
            # convert a relative link target into an absolute one
            link_target="$broken_symlink/$link_target"
        fi
        if [[ -d "$link_target" ]]; then
            LogPrintError "Symlink '$broken_symlink' -> '$link_target' refers to a non-existing directory on the rescue system."
            LogPrintError "It will not be copied by default. You can include '$link_target' via the 'COPY_AS_IS' configuration variable."
        elif test "$link_target" ; then
            # Never copy symlink targets in /proc/ /sys/ /dev/ or /run/ into the ReaR recovery system
            # for example the symlink /etc/mtab that points to /proc/self/mounts
            # cf. https://github.com/rear/rear/issues/2111
            # also cf. the scripts
            # finalize/GNU/Linux/250_migrate_disk_devices_layout.sh
            # finalize/GNU/Linux/250_migrate_lun_wwid.sh
            # finalize/GNU/Linux/280_migrate_uuid_tags.sh
            # finalize/GNU/Linux/320_migrate_network_configuration_files.sh
            if echo $link_target | egrep -q '^/(proc|sys|dev|run)/' ; then
                DebugPrint "Skip copying broken symlink '$broken_symlink' target '$link_target' on /proc/ /sys/ /dev/ or /run/"
                continue
            fi
            # The leading '.' is crucial to create the parent directories inside the current working directory ROOTFS_DIR
            # and to copy the symlink target into the current working directory ROOTFS_DIR:
            mkdir $v -p .$( dirname $link_target ) || LogPrintError "Failed to make parent directories for symlink target '$link_target'"
            # Continue even after "Failed to make parent directories for symlink target ..." and let 'cp' also fail
            # to also show the explicit "Failed to copy symlink target ..." message to the user:
            cp $v --preserve=all $link_target .$link_target || LogPrintError "Failed to copy target of symlink '$broken_symlink' -> '$link_target'"
        else
            LogPrintError "Broken symlink '$broken_symlink' in recovery system because 'readlink' cannot determine its link target"
        fi
    done
popd

