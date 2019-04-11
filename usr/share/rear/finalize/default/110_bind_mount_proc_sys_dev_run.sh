
# bind-mount /proc /sys /dev and /run from the currently running recovery system
# into the target system at TARGET_FS_ROOT, see
# https://github.com/rear/rear/issues/2045
#
# /proc /sys /dev and /run are in general needed by various finalize stage scripts
# (in particular to recreate the initrd and to reinstall the bootloader)
# so that all of them should be bind-mounted at the beginning of the finalize stage.
#
# umounting them is undesirable because it is better when also after "rear recover"
# things still work in a "chroot TARGET_FS_ROOT" environment so that the user
# can more easily adapt things after "rear recover", e.g. recreate his initrd
# or reinstall his bootloader even after a successful run of "rear recover"
# where 'a successful run' only means it did not error out but there
# could have been real errors that are only reported to the user (cf. below).
#
# This script does not error out because at this late state of "rear recover"
# (i.e. after the backup was restored) I <jsmeix@suse.de> consider it
# too hard to abort "rear recover" when it failed to bind-mount something.
# Such an error is only reported to the user via a LogPrintError message
# so that after "rear recover" finished he can manually fix things as needed.

local mount_olddir=""
# That variable name is 'mount_olddir' because on SLES10 'man mount' reads
#   Since Linux 2.4.0 it is possible to remount part of the file hierarchy somewhere else. The call is
#       mount --bind olddir newdir
#   After this call the same contents is accessible in two places.
# SLES10 has Linux 2.6 so that the 'mount --bind ...' call below may even work on SLES10
# at least in theory, see below what happens in practice on SLES11:
for mount_olddir in proc sys dev run ; do
    # Each of /proc /sys /dev and /run gets only bind-mounted into TARGET_FS_ROOT
    # when each one is also mounted in the currently running recovery system
    # to make things in TARGET_FS_ROOT behave same as in the recovery system.
    # When one of /proc /sys /dev and /run is not mounted in the recovery system
    # it exists only as an empty directory in TARGET_FS_ROOT that was created
    # by usr/share/rear/restore/default/900_create_missing_directories.sh
    # cf. https://github.com/rear/rear/issues/2035#issuecomment-463953847
    if ! mountpoint /$mount_olddir ; then
        Log "/$mount_olddir not mounted - cannot bind-mount it at $TARGET_FS_ROOT/$mount_olddir"
        if test "dev" = $mount_olddir ; then
            # Special case code to keep things still working on SLES11:
            # On SLES11 it does not work to bind-mount /dev on TARGET_FS_ROOT/dev
            # see https://github.com/rear/rear/issues/2045#issuecomment-481195463
            # because within the recovery system /dev is no mountpoint
            # (in a running SLES11 system 'mount' shows "udev on /dev type tmpfs") and
            # within the recovery system bind-mounting of the /dev directory fails.
            # It seems the root cause is that within the recovery system / is no mountpoint
            # like in a normal running system where e.g. /dev/sda2 is mounted on /
            # but within the recovery system / is the plain content of ReaR's initrd
            # so /dev does not belong to any mountpoint and that lets bind-mount fail.
            # It also does not make things work to mount 'devtmpfs' on TARGET_FS_ROOT/dev
            # because "mount -t devtmpfs none $TARGET_FS_ROOT/dev" works but it results
            # that in TARGET_FS_ROOT/dev only the plain kernel device nodes exist
            # but none of their symlinks (e.g. in /dev/disk/by-id and /dev/disk/by-uuid)
            # that are created by udev (because udev does not run inside TARGET_FS_ROOT)
            # and without those device node symlinks 'mkinitrd' fails.
            # To keep things still working on SLES11 we do here basically the same
            # as we did in our old finalize/default/100_populate_dev.sh that was:
            #   # many systems now use udev and thus have an empty /dev
            #   # this prevents our chrooted grub install later on, so we copy
            #   # the /dev from our rescue system to the freshly installed system
            #   cp -fa /dev $TARGET_FS_ROOT/
            # cf. https://github.com/rear/rear/issues/2045#issuecomment-464737610
            DebugPrint "Copying /dev contents from ReaR recovery system to $TARGET_FS_ROOT/dev"
            # But only a plain "cp -fa /dev $TARGET_FS_ROOT/" would be especially dirty because
            # it would copy device node files into TARGET_FS_ROOT after the backup was restored
            # (i.e. it would write and modify files on the sacrosanct user's target system disk)
            # and it would be especially sneaky because usually on the rebooted target system
            # something will be mounted on /dev (e.g. on SLES11 "udev on /dev type tmpfs")
            # so that our copied device nodes on the target system disk would get obscured and
            # hidden behind what is mounted on /dev in the normal running target system.
            # To avoid such dirtiness and sneakiness we first mount TARGET_FS_ROOT/dev as 'tmpfs'
            # and then copy all /dev contents from the recovery system into TARGET_FS_ROOT/dev
            # which makes the recovery system /dev contents available at TARGET_FS_ROOT/dev
            # only as long as the recovery system runs but on the rebooted target system
            # its original unmodified /dev will be there again:
            mount -t tmpfs tmpfs $TARGET_FS_ROOT/dev || DebugPrint "Failed to mount 'tmpfs' on $TARGET_FS_ROOT/dev"
            # Do not error out at this late state of "rear recover" but inform the user:
            cp -a /dev/. $TARGET_FS_ROOT/dev || LogPrintError "Failed to copy /dev contents from ReaR recovery system to $TARGET_FS_ROOT/dev"
        fi
        continue
    fi
    # Do an enforced re-mount in any case even if it is already mounted
    # to enforce a clean state at the beginning of the finalize stage:
    umount $TARGET_FS_ROOT/$mount_olddir && sleep 1
    # Do not error out at this late state of "rear recover" but inform the user:
    mount --bind /$mount_olddir $TARGET_FS_ROOT/$mount_olddir || LogPrintError "Failed to bind-mount /$mount_olddir at $TARGET_FS_ROOT/$mount_olddir"
done

