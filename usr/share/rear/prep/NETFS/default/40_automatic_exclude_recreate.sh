
# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

# Verify a local backup directory in BACKUP_URL=file:///path and
# add its mountpoint to the EXCLUDE_RECREATE array (if necessary).

local scheme=$( url_scheme $BACKUP_URL )
local backup_directory=$( url_path $BACKUP_URL )
local backup_directory_mountpoint=""

case $scheme in
    (file)
        # if user added path manually then there is no need to do it again
        # FIXME: I <jsmeix@suse.de> have no idea what the above comment line means.
        #
        # When the backup directory does not yet exist, 'df -P' results nothing on stdout and
        # when the backup directory does not yet exist it means it will be created at '/'.
        # But when the backup is stored in a directory on the same filesystem as '/' is
        # then it results a backup.tar.gz that contains itself in a non-yet-complete state
        # because all of the '/' filesystem is included in the backup.
        # To avoid various weird issues when the backup contains itself
        # a backup directory in the '/' filesystem is simply forbidden
        # regardless that a backup inside itself may not result fatal errors
        # see https://github.com/rear/rear/issues/926
        test -e "backup_directory" || Error "URL '$BACKUP_URL' would result the backup directory '$backup_directory' in the '/' filesystem which is forbidden."
        test -d "backup_directory" || Error "URL '$BACKUP_URL' specifies '$backup_directory' which is not a directory."
        backup_directory_mountpoint=$( df -P "$backup_directory" 2>/dev/null | tail -1 | awk '{print $6}' )
        test "/" = "$backup_directory_mountpoint" && Error "URL '$BACKUP_URL' has the backup directory '$backup_directory' in the '/' filesystem which is forbidden."
        # When the mountpoint of the backup directory is not yet excluded add its mountpoint to the EXCLUDE_RECREATE array:
        if ! grep -q "$backup_directory_mountpoint" <<< $( echo ${EXCLUDE_RECREATE[@]} ) ; then
            EXCLUDE_RECREATE=( "${EXCLUDE_RECREATE[@]}" "fs:$backup_directory_mountpoint" )
        fi
        ;;
esac

