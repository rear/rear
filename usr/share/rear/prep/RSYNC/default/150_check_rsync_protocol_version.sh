# 150_check_rsync_protocol_version.sh
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
# try to grab the rsync protocol version of rsync on the remote server

local remote_mountpoint host path proto
host="$(rsync_host "$BACKUP_URL")"
path="$(rsync_path "$BACKUP_URL")"
proto="$(rsync_proto "$BACKUP_URL")"

if [ -z "$RSYNC_PROTOCOL_VERSION" ]; then

    case $proto in

    (ssh)
        ssh $(rsync_remote_ssh "$BACKUP_URL") rsync --version >"$TMP_DIR/rsync_protocol" 2>&1 \
            || Error "Secure shell connection not setup properly [$(rsync_remote_ssh "$BACKUP_URL")]"
        if grep -q "protocol version" "$TMP_DIR/rsync_protocol" ; then
            RSYNC_PROTOCOL_VERSION=$(grep 'protocol version' "$TMP_DIR/rsync_protocol" | awk '{print $6}')
        else
            RSYNC_PROTOCOL_VERSION=29   # being conservative (old rsync version < 3.0)
        fi
        ;;

    (rsync)
        Log "Warning: no way to check remote rsync protocol without ssh access"
        RSYNC_PROTOCOL_VERSION=29 # being conservative (old rsync)
        ;;
    esac
    Log "Remote rsync system ($host) uses rsync protocol version $RSYNC_PROTOCOL_VERSION"

else

    Log "Remote rsync system ($host) uses rsync protocol version $RSYNC_PROTOCOL_VERSION (overruled by user)"

fi

if [ "$(rsync_user "$BACKUP_URL")" != "root" -a $proto = "ssh" ]; then
    if [ $RSYNC_PROTOCOL_VERSION -gt 29 ]; then
        if grep -q "no xattrs" "$TMP_DIR/rsync_protocol"; then
            # no xattrs available in remote rsync, so --fake-super is not possible
            Error "rsync --fake-super not possible on system ($host) (no xattrs compiled in rsync)"
        else
            # when using --fake-super we must have user_xattr mount options on the remote mntpt
            remote_mountpoint=$(ssh $(rsync_remote_ssh "$BACKUP_URL") 'cd ${path}; df -P .' 2>/dev/null | tail -1 | awk '{print $6}')
            ssh $(rsync_remote_ssh "$BACKUP_URL") "cd ${path} && touch .is_xattr_supported && setfattr -n user.comment -v 'File created by ReaR to test if this filesystems supports extended attributes.' .is_xattr_supported && getfattr -n user.comment .is_xattr_supported 1>/dev/null; find .is_xattr_supported -empty -delete" \
                || Error "Remote file system $remote_mountpoint does not have user_xattr mount option set!"
            #BACKUP_RSYNC_OPTIONS+=( --xattrs --rsync-path="rsync --fake-super" )
            # see issue #366 for explanation of removing --xattrs
            #BACKUP_RSYNC_OPTIONS+=( --rsync-path="rsync --fake-super" )  # the " get lost during the backup operarion, therefore, use -M--fake-super instead
            BACKUP_RSYNC_OPTIONS+=( -M--fake-super )
        fi
    else
        Error "rsync --fake-super not possible on system ($host) (please upgrade rsync to 3.x)"
    fi
fi
