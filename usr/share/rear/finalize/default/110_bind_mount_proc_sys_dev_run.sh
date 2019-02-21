
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
# SLES10 has Linux 2.6 so that the 'mount --bind ...' call below should even work on SLES10.
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
        continue
    fi
    # Do an enforced re-mount in any case even if it is already mounted
    # to enforce a clean state at the beginning of the finalize stage:
    umount $TARGET_FS_ROOT/$mount_olddir && sleep 1
    # Do not error out at this late state of "rear recover" but inform the user:
    mount --bind /$mount_olddir $TARGET_FS_ROOT/$mount_olddir || LogPrintError "Failed to bind-mount /$mount_olddir at $TARGET_FS_ROOT/$mount_olddir"
done

