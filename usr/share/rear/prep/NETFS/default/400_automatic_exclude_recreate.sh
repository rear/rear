# 400_automatic_exclude_recreate.sh
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

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
        # When the backup is stored in a directory on the same filesystem as '/' is
        # it results a backup.tar.gz that contains itself (but in a not-yet-complete state)
        # because all of the '/' filesystem is included in the backup.
        # To avoid various weird issues when the backup contains itself
        # a backup directory in the '/' filesystem is simply forbidden
        # regardless that a backup inside itself may not result fatal errors
        # see https://github.com/rear/rear/issues/926
        if ! test -e "$backup_directory" ; then
            # When the backup directory does not yet exist, 'df -P' results nothing on stdout
            # which means the backup directory must be created so that 'df -P' can show its mountpoint
            # to find out whether or not the backup directory would be in the '/' filesystem:
            mkdir $v -p "$backup_directory" >&2 || Error "Could not create backup directory '$backup_directory' (from URL '$BACKUP_URL')."
        fi
        test -d "$backup_directory" || Error "URL '$BACKUP_URL' specifies '$backup_directory' which is not a directory."
        backup_directory_mountpoint=$( df -P "$backup_directory" | tail -1 | awk '{print $6}' )
        test "/" = "$backup_directory_mountpoint" && Error "URL '$BACKUP_URL' has the backup directory '$backup_directory' in the '/' filesystem which is forbidden."
        # When the mountpoint of the backup directory is not yet excluded add its mountpoint to the EXCLUDE_RECREATE array:
        if ! grep -q "$backup_directory_mountpoint" <<< $( echo ${EXCLUDE_RECREATE[@]} ) ; then
            EXCLUDE_RECREATE=( "${EXCLUDE_RECREATE[@]}" "fs:$backup_directory_mountpoint" )
        fi
        ;;
esac

