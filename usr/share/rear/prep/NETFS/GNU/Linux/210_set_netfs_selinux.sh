# Set NETFS_SELINUX based on backup program capabilities

# Determine if the backup program supports SELinux context preservation
case $(basename $BACKUP_PROG) in
    (tar)
        # TAR_SELINUX is set by 205_inspect_tar_capabilities.sh
        NETFS_SELINUX=${TAR_SELINUX:-0}
        ;;
    (rsync)
        # RSYNC_SELINUX is set by prep/RSYNC/GNU/Linux/200_selinux_in_use.sh
        NETFS_SELINUX=${RSYNC_SELINUX:-0}
        ;;
    (*)
        # For other backup programs, use BACKUP_PROG_SELINUX from config
        NETFS_SELINUX=${BACKUP_PROG_SELINUX:-0}
        ;;
esac
